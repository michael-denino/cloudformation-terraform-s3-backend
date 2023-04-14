#!/usr/bin/env bash

set -o errexit

# Pass a CloudFormation command as an argument to this script (e.g create-stack, delete-stack, etc.)
# Use --help for a list of available commands
COMMAND=$1
STACK_NAME=terraform-backend
VALID_ARGUMENTS=("create-stack" "delete-stacks" "describe-stacks" "describe-stack-events" "update-stack")

list_valid_arguments () {
  for argument in ${VALID_ARGUMENTS[@]}
  do
    echo ${argument}
  done
}

cloudformation () {
  case $COMMAND in
    "create-stack" | "update-stack")
      # Stack-level tags are applied to all supported resources in the CloudFormation stack
      aws cloudformation $COMMAND \
        --stack-name $STACK_NAME \
        --template-body file://$(dirname $0)/../tf-s3-backend.yaml \
        --tags Key=Name,Value=$STACK_NAME
      ;;
    "describe-stacks" | "delete-stack" | "describe-stack-events")
      aws cloudformation $COMMAND \
        --stack-name $STACK_NAME
      ;;
    "help" | "--help")
      echo -e "Commands:\n"
      list_valid_arguments
      ;;
    *)
      echo -e "Invalid argument: '${COMMAND}'\nUse --help to list available commands"
      exit 1
      ;;
  esac
}

cloudformation
