#!/bin/bash
set -euo pipefail

export AWS_DEFAULT_REGION=us-east-1

lstk aws s3 mb s3://localstack-thumbnails-app-images
lstk aws s3 mb s3://localstack-thumbnails-app-resized

lstk aws ssm put-parameter --name /localstack-thumbnail-app/buckets/images --type "String" --value "localstack-thumbnails-app-images"
lstk aws ssm put-parameter --name /localstack-thumbnail-app/buckets/resized --type "String" --value "localstack-thumbnails-app-resized"

lstk aws sns create-topic --name image_resize_failures
lstk aws sns subscribe \
    --topic-arn arn:aws:sns:us-east-1:000000000000:image_resize_failures \
    --protocol email \
    --notification-endpoint my-email@example.com

lambda_assume_role_policy='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"lambda.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

# Shared by all three Lambda functions, mirroring deployment/terraform's LambdasAccessSsm policy
lambdas_ssm_policy_arn=$(lstk aws iam create-policy \
    --policy-name LambdasAccessSsm \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "ssm:GetParameter",
                "Resource": "arn:aws:ssm:us-east-1:000000000000:parameter/localstack-thumbnail-app/*"
            }
        ]
    }' \
    --query Policy.Arn --output text)

# Presign Lambda

lstk aws iam create-role \
    --role-name PresignLambdaRole \
    --assume-role-policy-document "$lambda_assume_role_policy"

presign_s3_policy_arn=$(lstk aws iam create-policy \
    --policy-name PresignLambdaS3AccessPolicy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": ["s3:ListBucket", "s3:GetObject", "s3:PutObject"],
                "Resource": [
                    "arn:aws:s3:::localstack-thumbnails-app-images",
                    "arn:aws:s3:::localstack-thumbnails-app-images/*"
                ]
            }
        ]
    }' \
    --query Policy.Arn --output text)

lstk aws iam attach-role-policy --role-name PresignLambdaRole --policy-arn "$presign_s3_policy_arn"
lstk aws iam attach-role-policy --role-name PresignLambdaRole --policy-arn "$lambdas_ssm_policy_arn"

lstk aws lambda create-function \
    --function-name presign \
    --runtime python3.11 \
    --timeout 10 \
    --zip-file fileb://lambdas/presign/lambda.zip \
    --handler handler.handler \
    --role arn:aws:iam::000000000000:role/PresignLambdaRole \
    --environment Variables="{STAGE=local}"

lstk aws lambda wait function-active-v2 --function-name presign

lstk aws lambda create-function-url-config \
    --function-name presign \
    --auth-type NONE

# List images Lambda

lstk aws iam create-role \
    --role-name ListLambdaRole \
    --assume-role-policy-document "$lambda_assume_role_policy"

list_s3_policy_arn=$(lstk aws iam create-policy \
    --policy-name ListLambdaS3AccessPolicy \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": ["s3:ListBucket", "s3:GetObject"],
                "Resource": [
                    "arn:aws:s3:::localstack-thumbnails-app-images",
                    "arn:aws:s3:::localstack-thumbnails-app-images/*",
                    "arn:aws:s3:::localstack-thumbnails-app-resized",
                    "arn:aws:s3:::localstack-thumbnails-app-resized/*"
                ]
            }
        ]
    }' \
    --query Policy.Arn --output text)

lstk aws iam attach-role-policy --role-name ListLambdaRole --policy-arn "$list_s3_policy_arn"
lstk aws iam attach-role-policy --role-name ListLambdaRole --policy-arn "$lambdas_ssm_policy_arn"

lstk aws lambda create-function \
    --function-name list \
    --runtime python3.11 \
    --timeout 10 \
    --zip-file fileb://lambdas/list/lambda.zip \
    --handler handler.handler \
    --role arn:aws:iam::000000000000:role/ListLambdaRole \
    --environment Variables="{STAGE=local}"

lstk aws lambda wait function-active-v2 --function-name list

lstk aws lambda create-function-url-config \
    --function-name list \
    --auth-type NONE

# Resize Lambda

lstk aws iam create-role \
    --role-name ResizeLambdaRole \
    --assume-role-policy-document "$lambda_assume_role_policy"

resize_s3_policy_arn=$(lstk aws iam create-policy \
    --policy-name ResizeLambdaS3Buckets \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": ["s3:ListBucket", "s3:GetObject"],
                "Resource": [
                    "arn:aws:s3:::localstack-thumbnails-app-images",
                    "arn:aws:s3:::localstack-thumbnails-app-images/*"
                ]
            },
            {
                "Effect": "Allow",
                "Action": ["s3:ListBucket", "s3:GetObject", "s3:PutObject"],
                "Resource": [
                    "arn:aws:s3:::localstack-thumbnails-app-resized",
                    "arn:aws:s3:::localstack-thumbnails-app-resized/*"
                ]
            }
        ]
    }' \
    --query Policy.Arn --output text)

lstk aws iam attach-role-policy --role-name ResizeLambdaRole --policy-arn "$resize_s3_policy_arn"
lstk aws iam attach-role-policy --role-name ResizeLambdaRole --policy-arn "$lambdas_ssm_policy_arn"

lstk aws lambda create-function \
    --function-name resize \
    --runtime python3.11 \
    --timeout 10 \
    --zip-file fileb://lambdas/resize/lambda.zip \
    --handler handler.handler \
    --dead-letter-config TargetArn=arn:aws:sns:us-east-1:000000000000:image_resize_failures \
    --role arn:aws:iam::000000000000:role/ResizeLambdaRole \
    --environment Variables="{STAGE=local}"

lstk aws lambda wait function-active-v2 --function-name resize
lstk aws lambda put-function-event-invoke-config --function-name resize --maximum-event-age-in-seconds 3600 --maximum-retry-attempts 0

resize_sns_policy_arn=$(lstk aws iam create-policy \
    --policy-name ResizeLambdaSNS \
    --policy-document '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": "sns:Publish",
                "Resource": "arn:aws:sns:us-east-1:000000000000:image_resize_failures"
            },
            {
                "Effect": "Allow",
                "Action": "lambda:InvokeFunction",
                "Resource": "arn:aws:lambda:us-east-1:000000000000:function:resize"
            }
        ]
    }' \
    --query Policy.Arn --output text)

lstk aws iam attach-role-policy --role-name ResizeLambdaRole --policy-arn "$resize_sns_policy_arn"

lstk aws lambda add-permission \
    --function-name resize \
    --statement-id s3invoke \
    --action lambda:InvokeFunction \
    --principal s3.amazonaws.com \
    --source-arn arn:aws:s3:::localstack-thumbnails-app-images

fn_resize_arn=$(lstk aws lambda get-function --function-name resize --output json | jq -r .Configuration.FunctionArn)
lstk aws s3api put-bucket-notification-configuration \
    --bucket localstack-thumbnails-app-images \
    --notification-configuration "{\"LambdaFunctionConfigurations\": [{\"LambdaFunctionArn\": \"$fn_resize_arn\", \"Events\": [\"s3:ObjectCreated:*\"]}]}"

# Simple public S3 static website, unlike deployment/terraform's CloudFront + Origin
# Access Identity setup — kept as a plain bucket here for CLI-deploy simplicity.
lstk aws s3 mb s3://webapp
lstk aws s3 sync --delete ./website s3://webapp
lstk aws s3 website s3://webapp --index-document index.html

echo
echo "Fetching function URL for 'presign' Lambda..."
lstk aws lambda list-function-url-configs --function-name presign --output json | jq -r '.FunctionUrlConfigs[0].FunctionUrl'
echo "Fetching function URL for 'list' Lambda..."
lstk aws lambda list-function-url-configs --function-name list --output json | jq -r '.FunctionUrlConfigs[0].FunctionUrl'

echo "Now open the Web app under https://webapp.s3-website.localhost.localstack.cloud:4566/"
echo "and paste the function URLs above (make sure to use https:// as protocol)"
