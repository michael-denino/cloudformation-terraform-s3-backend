#!/usr/bin/env bash

set -o nounset
set -o errexit

# pass the cloudformation command as the first arguemnt (e.g create-stack, update-stack, etc.)
# pass the environment name as the second arguemnt (e.g dev, prod, etc.)
# pass the project name as the third arguemnt (must be unique as S3 buckets are globally unique)
# i.e. ./stack.sh create-stack prod company-name
COMMAND=$1
ENVIRONMENT=$2
PROJECT=$3

# Stack-level tags are applied to all supported resources in the CloudFormation stack
aws cloudformation $COMMAND \
--stack-name $ENVIRONMENT-$PROJECT-terraform-backend \
--template-body file://../tf-s3-backend.yaml \
--parameters ParameterKey=StateBucketName,ParameterValue=$ENVIRONMENT-$PROJECT-terraform-backend \
             ParameterKey=LockTableName,ParameterValue=$ENVIRONMENT-$PROJECT-terraform-backend \
--tags Key=Name,Value=$ENVIRONMENT-$PROJECT-terraform-backend \
       Key=environment,Value=$ENVIRONMENT
