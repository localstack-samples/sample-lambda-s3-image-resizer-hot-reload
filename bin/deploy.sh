#!/bin/bash

awslocal s3 mb s3://localstack-thumbnails-app-images
awslocal s3 mb s3://localstack-thumbnails-app-resized

awslocal ssm put-parameter --name /localstack-thumbnail-app/buckets/images --value "localstack-thumbnails-app-images"
awslocal ssm put-parameter --name /localstack-thumbnail-app/buckets/resized --value "localstack-thumbnails-app-resized"

awslocal sns create-topic --name failed-resize-topic
awslocal sns subscribe \
    --topic-arn arn:aws:sns:us-east-1:000000000000:failed-resize-topic \
    --protocol email \
    --notification-endpoint my-email@example.com

(cd lambdas/presign; rm -f lambda.zip; zip lambda.zip handler.py)
awslocal lambda create-function \
    --function-name presign \
    --runtime python3.9 \
    --timeout 10 \
    --zip-file fileb://lambdas/presign/lambda.zip \
    --handler handler.handler \
    --role arn:aws:iam::000000000000:role/lambda-role

awslocal lambda create-function-url-config \
    --function-name presign \
    --auth-type NONE

(
    cd lambdas/resize
    rm -rf package lambda.zip
    mkdir package
    pip install -r requirements.txt -t package
    zip lambda.zip handler.py
    cd package
    zip -r ../lambda.zip *;
)
awslocal lambda create-function \
    --function-name resize \
    --runtime python3.9 \
    --timeout 10 \
    --zip-file fileb://lambdas/resize/lambda.zip \
    --handler handler.handler \
    --dead-letter-config TargetArn=arn:aws:sns:us-east-1:000000000000:failed-resize-topic \
    --role arn:aws:iam::000000000000:role/lambda-role

awslocal s3api put-bucket-notification-configuration \
    --bucket localstack-thumbnails-app-images \
    --notification-configuration "{\"LambdaFunctionConfigurations\": [{\"LambdaFunctionArn\": \"$(awslocal lambda get-function --function-name resize | jq -r .Configuration.FunctionArn)\", \"Events\": [\"s3:ObjectCreated:*\"]}]}"

awslocal s3 mb s3://webapp
awslocal s3 sync --delete ./website s3://webapp
awslocal s3 website s3://webapp --index-document index.html
