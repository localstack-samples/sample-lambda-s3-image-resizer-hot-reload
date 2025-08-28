# Serverless Image Resizer with Lambda and S3 on LocalStack

[![GitHub Actions](https://github.com/localstack-samples/sample-lambda-s3-image-resizer-hot-reload/actions/workflows/integration-test.yml/badge.svg)](https://github.com/localstack-samples/sample-lambda-s3-image-resizer-hot-reload/actions/workflows/integration-test.yml)
[![CircleCI](https://dl.circleci.com/status-badge/img/gh/localstack-samples/sample-lambda-s3-image-resizer-hot-reload/tree/main.svg?style=shield)](https://dl.circleci.com/status-badge/redirect/gh/localstack-samples/sample-lambda-s3-image-resizer-hot-reload/tree/main)
[![AWS CodeBuild](https://codebuild.eu-central-1.amazonaws.com/badges?uuid=eyJlbmNyeXB0ZWREYXRhIjoiUUVDZExZT0ovUm5YejlKcHlXeGpuT1pRaC9hSzdDcFJVYlMvZzl0emtnWW5qcVdQUGY3YlJYWnBJeEdoOHd0OVkvd29XTUxuL2p3d3hVS0NFRnFlTzhRPSIsIml2UGFyYW1ldGVyU3BlYyI6IjQrdHhqVGY1N24ycTEvQkMiLCJtYXRlcmlhbFNldFNlcmlhbCI6MX0%3D&branch=codebuild-sample)](https://eu-central-1.codebuild.aws.amazon.com/project/eyJlbmNyeXB0ZWREYXRhIjoiOGpTQnR0a0J6ZnYwN3hNQ21DVkFoUU8zWTc4TExSaGk0b2p5UkVyNWhHSXhLSWZUSWt3eE1PUnpLZTRMWld2U3l3bVBWa2Frc084YjJ6UFZDRjNlcTc0U0xOa2lqVU1qZXdJMUFzdEVudz09IiwiaXZQYXJhbWV0ZXJTcGVjIjoib1FaZmhKMHZkc0NTbmdqcSIsIm1hdGVyaWFsU2V0U2VyaWFsIjoxfQ%3D%3D)
[![GitLabCI](https://gitlab.com/localstack.cloud/samples/sample-serverless-image-resizer-s3-lambda/badges/main/pipeline.svg?ignore_skipped=true)](https://gitlab.com/localstack.cloud/samples/sample-serverless-image-resizer-s3-lambda)

| Key          | Value                                                                                      |
| ------------ | ------------------------------------------------------------------------------------------ |
| Environment  | LocalStack, AWS                                                                            |
| Services     | S3, Lambda, SNS, SES, SSM                                                                  |
| Integrations | AWS SDK, AWS CLI, pytest                                                                   |
| Categories   | Serverless, S3 notifications, S3 website, Lambda function URLs                             |
| Level        | Intermediate                                                                               |
| Use Case     | Lambda DevX, Integration Testing                                                           |
| GitHub       | [Repository link](https://github.com/localstack-samples/sample-lambda-s3-image-resizer-hot-reload) |

## Introduction

This sample demonstrates how to build a serverless image resizing application using AWS Lambda, S3, and related services. The application features a simple web frontend that allows users to upload images, which are then automatically resized using Lambda functions triggered by S3 events. To test this application sample, we will demonstrate how you use LocalStack to deploy the infrastructure on your developer machine and test the complete workflow locally. We will also show how to use Lambda hot reloading for rapid development cycles and comprehensive integration testing to ensure the application works end-to-end.

## Architecture

The following diagram shows the architecture that this sample application builds and deploys:

![Architecture overview](images/architecture.png)

- [S3 Buckets](https://docs.localstack.cloud/aws/services/s3/) for storing original and resized images, plus hosting the static website
- [Lambda Functions](https://docs.localstack.cloud/aws/services/lambda/) for generating pre-signed URLs, image processing, and listing images.
- S3 Event Notifications to trigger the resize Lambda when new images are uploaded.
- [SNS](https://docs.localstack.cloud/aws/services/sns/) and [SES](https://docs.localstack.cloud/aws/services/ses/) for error notifications and email alerts.
- [SSM Parameter Store](https://docs.localstack.cloud/aws/services/ssm/) for configuration management.

## Prerequisites

- [`localstack` CLI](https://docs.localstack.cloud/getting-started/installation/#localstack-cli) with a [`LOCALSTACK_AUTH_TOKEN`](https://docs.localstack.cloud/getting-started/auth-token/).
- [AWS CLI](https://docs.localstack.cloud/user-guide/integrations/aws-cli/) with the [`awslocal` wrapper](https://docs.localstack.cloud/user-guide/integrations/aws-cli/#localstack-aws-cli-awslocal).
- [Python 3.11](https://www.python.org/downloads/) (same version as the Lambda runtime)
- [`make`](https://www.gnu.org/software/make/) (**optional**, but recommended for running the sample application)

## Installation

To run the sample application, you need to install the required dependencies.

First, clone the repository:

```shell
git clone https://github.com/localstack/sample-lambda-s3-image-resizer-hot-reload.git
```

Then, navigate to the project directory:

```shell
cd sample-lambda-s3-image-resizer-hot-reload
```

Create a virtual environment and install the development dependencies:

```shell
python -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
```

## Deployment

Start LocalStack with the `LOCALSTACK_AUTH_TOKEN` pre-configured:

```shell
localstack auth set-token <your-auth-token>
localstack start
```

Before deploying the sample application, you need to build the Lambda functions. Run the following command:

```shell
deployment/build-lambdas.sh
```

To deploy the sample application, run the following command:

```shell
deployment/awslocal/deploy.sh
```

The output will show the Lambda function URLs that you can use in the web application:

```shell
Fetching function URL for 'presign' Lambda...
https://abcdef123456.lambda-url.us-east-1.localhost.localstack.cloud:4566/
Fetching function URL for 'list' Lambda...
https://789012345678.lambda-url.us-east-1.localhost.localstack.cloud:4566/

Now open the Web app under https://webapp.s3-website.localhost.localstack.cloud:4566/
and paste the function URLs above (make sure to use https:// as protocol)
```

## Testing

Visit the web application at `https://webapp.s3-website.localhost.localstack.cloud:4566/` and paste the function URLs from the deployment output into the form fields. You can then upload an image and see it get automatically resized.

https://user-images.githubusercontent.com/3996682/229314248-86122e9e-0150-4292-b889-401e6fb8f398.mp4

You can run full end-to-end integration tests using the following command:

```shell
pytest tests/
```

## Use Cases

### Lambda DevX

This sample demonstrates LocalStack's Lambda hot reloading capability, which enables immediate reflection of code changes without redeployment. With hot reloading, you can achieve fast feedback cycles during development.

To enable hot reloading for the `list` Lambda function, use the special `hot-reload` bucket name with an absolute path to your Lambda code:

```shell
awslocal lambda update-function-code --function-name list \
  --s3-bucket hot-reload --s3-key "$(pwd)/lambdas/list"
```

This setup allows you to:

- Modify the Lambda handler code in `lambdas/list/handler.py`
- See changes immediately reflected in the UI without rebuilding or redeploying
- Iterate quickly on Lambda logic during development
- Test different response formats or business logic in real-time

The hot reloading feature uses LocalStack's ability to watch local file changes and automatically update the Lambda function's code, making development cycles significantly faster than traditional serverless development workflows.

### Integration Testing

The sample includes comprehensive integration tests that demonstrate end-to-end testing patterns for serverless applications. The test suite validates the complete workflow from image upload through processing to failure handling.

Key testing scenarios include:

- **Image Processing Workflow**:
    - Uploads a test image to the source S3 bucket
    - Waits for the resize Lambda to process the image (triggered by S3 event notification)
    - Verifies the resized image appears in the target bucket
    - Confirms the resized image is smaller than the original
    - Cleans up test resources
- **Error Handling and Notifications**:
    - Uploads a non-image file to trigger Lambda failure
    - Verifies that SNS receives the failure notification
    - Confirms SES sends an email alert using LocalStack's SES testing endpoint
    - Uses LocalStack's `/_aws/ses` endpoint to inspect sent emails without requiring real email infrastructure

The integration tests demonstrate several LocalStack capabilities:

- **S3 Waiters**: Using `s3.get_waiter("object_exists")` to wait for asynchronous processing
- **Lambda Waiters**: Ensuring functions are active before running tests
- **SES Developer Endpoints**: Testing email functionality without external dependencies
- **Event-Driven Testing**: Validating S3 event notifications trigger Lambda functions correctly

These patterns enable reliable testing of complex serverless applications in isolated local environments.

## Summary

This sample application demonstrates how to build, deploy, and test a complete serverless image processing workflow using LocalStack. It showcases the following patterns:

- Building event-driven serverless applications with S3, Lambda, and SNS integration
- Using S3 pre-signed URLs for direct client-side uploads
- Implementing error handling with SNS and SES notifications
- Leveraging Lambda function URLs for HTTP-triggered functions
- Utilizing LocalStack's hot reloading for rapid development cycles
- Writing comprehensive integration tests for serverless applications
- Using LocalStack's developer endpoints for testing email functionality

## Learn More

- [LocalStack Lambda Hot Reloading](https://docs.localstack.cloud/aws/tooling/lambda-tools/hot-reloading/)
- [S3 Event Notifications](https://docs.aws.amazon.com/AmazonS3/latest/userguide/EventNotifications.html)
- [Lambda Function URLs](http://docs.aws.amazon.com/lambda/latest/dg/urls-configuration.html)
- [LocalStack Internal Endpoints](https://docs.localstack.cloud/aws/capabilities/networking/internal-endpoints/)
- [AWS SDK for Python](https://docs.localstack.cloud/aws/integrations/aws-sdks/python-boto3/)
