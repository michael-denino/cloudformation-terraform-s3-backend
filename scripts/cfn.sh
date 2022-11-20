#!/usr/bin/env bash

set -o nounset
set -o errexit

# pass the cloudformation command as the first arguemnt (e.g create-stack, update-stack, delete-stack, etc.)
# pass the environment name as the second arguemnt (e.g dev, prod, etc.)
# pass a purpose description as the third arguemnt
# i.e. $ ./stack.sh create-stack dev test
COMMAND=$1
ENVIRONMENT=$2
PURPOSE=$3
STACK_NAME=$ENVIRONMENT-$PURPOSE-terraform-backend
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)

case $COMMAND in
    "delete-stack" | "describe-stacks")
        aws cloudformation $COMMAND \
            --stack-name $STACK_NAME
        ;;
    *)
        # Stack-level tags are applied to all supported resources in the CloudFormation stack
        aws cloudformation $COMMAND \
            --stack-name $STACK_NAME \
            --template-body file://../tf-s3-backend.yaml \
            --parameters ParameterKey=StateBucketName,ParameterValue=$STACK_NAME-$AWS_ACCOUNT \
            ParameterKey=LockTableName,ParameterValue=$STACK_NAME \
            --tags Key=Name,Value=$STACK_NAME \
            Key=environment,Value=$ENVIRONMENT \
            Key=purpose,Value=$PURPOSE
        ;;
esac
