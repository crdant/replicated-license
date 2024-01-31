# Configuration
PROJECT_DIR := $(shell pwd)

AWS_REGION := us-west-2
API_TOKEN  := $(shell yq .token ${HOME}/.replicated/config.yaml)

SRC_DIR    := $(PROJECT_DIR)/src
BUILD_DIR  := $(PROJECT_DIR)/build
DEPLOY_DIR := $(PROJECT_DIR)/deploy

FUNCTION_NAME := create-license
LAMBDA_DIR    := $(SRC_DIR)/$(FUNCTION_NAME)
TERRAFORM_DIR := $(DEPLOY_DIR)/terraform
PACKAGE_NAME  := $(BUILD_DIR)/$(FUNCTION_NAME).zip

TF_FLAGS := -var="build_directory=$(BUILD_DIR)" -var "aws_region=$(AWS_REGION)" -var "api_token=$(API_TOKEN)" -var "owner=${USER}"

.PHONY: prepare package deploy clean

# Default target
all: deploy

# prepare the build directory
prepare: 
	@mkdir -p $(BUILD_DIR)/$(FUNCTION_NAME)
	@cp -r $(LAMBDA_DIR)/* $(BUILD_DIR)/$(FUNCTION_NAME)
 
# Package Lambda function
package: prepare
	cd $(BUILD_DIR)/$(FUNCTION_NAME) && \
		pip install -r requirements.txt -t . --upgrade && \
		zip -r $(PACKAGE_NAME) . 

# Deploy with Terraform
plan: package
	cd $(TERRAFORM_DIR) && \
		terraform init && \
		terraform plan $(TF_FLAGS)

# Deploy with Terraform
deploy: package
	cd $(TERRAFORM_DIR) && \
		terraform init && \
		terraform apply $(TF_FLAGS) -auto-approve

# Clean up the package
clean:
	rm -rf $(BUILD_DIR)/*
