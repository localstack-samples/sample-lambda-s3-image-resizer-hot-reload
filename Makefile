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
	@command -v aws > /dev/null 2>&1 || { echo "AWS CLI is not installed. Please install AWS CLI and try again."; exit 1; }
	@command -v lstk > /dev/null 2>&1 || { echo "lstk is not installed. Please install lstk and try again."; exit 1; }
	@command -v python3 > /dev/null 2>&1 || { echo "Python 3 is not installed. Please install Python 3 and try again."; exit 1; }
	@command -v jq > /dev/null 2>&1 || { echo "jq is not installed. Please install jq and try again."; exit 1; }
	@echo "All required prerequisites are available."
	
## Install dependencies
install:
	@echo "Installing dependencies..."
	python3 -m venv venv
	bash -c "source venv/bin/activate && pip install -r requirements-dev.txt"
	@echo "Dependencies installed successfully."

## Build the Lambda functions
build-lambdas:
	@echo "Building the Lambda functions..."
	bash -c "source venv/bin/activate && deployment/build-lambdas.sh"
	@echo "Lambda functions built successfully."

## Deploy the application locally using `lstk aws`, the LocalStack AWS CLI proxy
deploy:
	@echo "Deploying the application..."
	@make build-lambdas
	deployment/aws/deploy.sh
	@echo "Application deployed successfully."

## Deploy the application locally using `lstk tf`, the LocalStack Terraform CLI proxy
deploy-terraform:
	@command -v terraform > /dev/null 2>&1 || { echo "Terraform is not installed. Please install Terraform and try again."; exit 1; }
	@command -v lstk > /dev/null 2>&1 || { echo "lstk is not installed. Please install lstk and try again."; exit 1; }
	@echo "Deploying the application..."
	@make build-lambdas
	cd deployment/terraform && lstk tf init && lstk tf apply --auto-approve
	@echo "Application deployed successfully."

## Run tests locally
test:
	@echo "Running tests..."
	bash -c "source venv/bin/activate && pytest tests"
	@echo "Tests completed successfully."

## Start LocalStack
start:
	@echo "Starting LocalStack..."
	@test -n "${LOCALSTACK_AUTH_TOKEN}" || (echo "LOCALSTACK_AUTH_TOKEN is not set. Find your token at https://app.localstack.cloud/workspace/auth-token"; exit 1)
	@LOCALSTACK_AUTH_TOKEN=$(LOCALSTACK_AUTH_TOKEN) lstk start
	@echo "LocalStack started successfully."

## Stop LocalStack
stop:
	@echo "Stopping LocalStack..."
	@lstk stop
	@echo "LocalStack stopped successfully."

## Save the logs in a separate file
logs:
		@lstk logs > logs.txt

.PHONY: usage install start build-lambdas deploy deploy-terraform test logs stop
