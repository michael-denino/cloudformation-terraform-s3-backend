#!/usr/bin/env bash

set -o nounset
set -o errexit

# pass the cloudformation command as an arguemnt (e.g create-stack, update-stack, delete-stack, etc.)
# i.e. $ ./stack.sh create-stack
COMMAND=$1
STACK_NAME=terraform-backend

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
      --tags Key=Name,Value=$STACK_NAME
  ;;
esac
