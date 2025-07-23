export AWS_ACCESS_KEY_ID ?= test
export AWS_SECRET_ACCESS_KEY ?= test
export AWS_DEFAULT_REGION=us-east-1
SHELL := /bin/bash

## Show this help
usage:
		@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

## Check if all required prerequisites are installed
check:
	@command -v docker > /dev/null 2>&1 || { echo "Docker is not installed. Please install Docker and try again."; exit 1; }
	@command -v localstack > /dev/null 2>&1 || { echo "LocalStack is not installed. Please install LocalStack and try again."; exit 1; }
	@command -v aws > /dev/null 2>&1 || { echo "AWS CLI is not installed. Please install AWS CLI and try again."; exit 1; }
	@command -v awslocal > /dev/null 2>&1 || { echo "awslocal is not installed. Please install awslocal and try again."; exit 1; }
	@command -v python > /dev/null 2>&1 || { echo "Python is not installed. Please install Python and try again."; exit 1; }
	@command -v jq > /dev/null 2>&1 || { echo "jq is not installed. Please install jq and try again."; exit 1; }
	@echo "All required prerequisites are available."
	
## Install dependencies
install:
	@echo "Installing dependencies..."
	pip install virtualenv
	virtualenv venv
	bash -c "source venv/bin/activate && pip install -r requirements-dev.txt"
	@echo "Dependencies installed successfully."

## Build the Lambda functions
build-lambdas:
	@echo "Building the Lambda functions..."
	bash -c "source venv/bin/activate && bin/build_lambdas.sh"
	@echo "Lambda functions built successfully."

## Deploy the application locally using `awslocal`, a wrapper for the AWS CLI
deploy:
	@echo "Deploying the application..."
	@make build-lambdas
	deployment/awslocal/deploy.sh
	@echo "Application deployed successfully."

## Deploy the application locally using `tflocal`, a wrapper for the Terraform CLI
deploy-terraform:
	@command -v terraform > /dev/null 2>&1 || { echo "Terraform is not installed. Please install Terraform and try again."; exit 1; }
	@which tflocal || pip install terraform-local
	@echo "Deploying the application..."
	@make build-lambdas
	deployment/tflocal/deploy.sh
	@echo "Application deployed successfully."

## Run tests locally
test:
	@echo "Running tests..."
	bash -c "source venv/bin/activate && pytest tests"
	@echo "Tests completed successfully."

## Start LocalStack
start:
	@echo "Starting LocalStack..."
	@LOCALSTACK_AUTH_TOKEN=$(LOCALSTACK_AUTH_TOKEN) localstack start -d
	@echo "LocalStack started successfully."

## Stop LocalStack
stop:
	@echo "Stopping LocalStack..."
	@localstack stop
	@echo "LocalStack stopped successfully."

## Make sure the LocalStack container is up
ready:
		@echo Waiting on the LocalStack container...
		@localstack wait -t 30 && echo LocalStack is ready to use! || (echo Gave up waiting on LocalStack, exiting. && exit 1)

## Save the logs in a separate file
logs:
		@localstack logs > logs.txt

.PHONY: usage install start ready build-lambdas deploy test logs stop
