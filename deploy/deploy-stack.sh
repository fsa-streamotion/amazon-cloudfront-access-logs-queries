#!/bin/bash
set -x #echo on
set -v # verbose. include comments.

# variables. lets keep same for all accounts
STACK_NAME=alb-restructure-stack
REGION=ap-southeast-2
SAM_TEMPLATE_FILE_PATH="../template.yaml"
FN_RECEIVE_S3_EVENTS="MoveNewAccessLogsFn"

# specific to this account

# expect following exports before running this script
# export AWS_PROFILE=streamotion-platform-nonprod
# export ACCOUNT_NAME=streamotion-platform-nonprod

if [ -z "$AWS_PROFILE" ]
	then
		echo "AWS_PROFILE Env variable empty" && exit 1
fi

if [ -z "$ACCOUNT_NAME" ]
	then
		echo "ACCOUNT_NAME empty. Assuming ACCOUNT_NAME=AWS_PROFILE" 
    ACCOUNT_NAME=$AWS_PROFILE
fi

echo "AWS_PROFILE name set to: "$AWS_PROFILE
echo "ACCOUNT_NAME name set to: "$ACCOUNT_NAME



source env/$ACCOUNT_NAME.vars 
# ACCOUNT_NAME=streamotion-platform-nonprod 
# ACCOUNT="841472843274"
# OUTPUT_TEMPLATE_FILE_LOCAL=output-templates/"cfn_template_"$ACCOUNT_NAME".yaml"
# OUTPUT_TEMPLATE_FILE_S3_BUCKET="cf-templates-ege6k8witfa7-ap-southeast-2"
# OUTPUT_TEMPLATE_FILE_S3_PREFIX=$STACK_NAME/sam-packaged-template/v1
# CFN_PARAM_FILE="env/streamotion-platform-nonprod.parameters"

# SourceS3Bucket="s3-platform-nonprod-foxsports-s3logs"
# SourceS3Prefix="alb-access-logs"



# excecute commands

# action: sam package
# # package the sam template. dump a copy locally. also in s3
sam package --template-file $SAM_TEMPLATE_FILE_PATH --output-template-file $OUTPUT_TEMPLATE_FILE_LOCAL  --s3-bucket $OUTPUT_TEMPLATE_FILE_S3_BUCKET --s3-prefix $OUTPUT_TEMPLATE_FILE_S3_PREFIX


# action: sam deploy
# # CFN_PARAM_FILE would be replaced by sceptre env
sam deploy --debug  --template-file $OUTPUT_TEMPLATE_FILE_LOCAL --stack-name $STACK_NAME --region $REGION --s3-bucket $OUTPUT_TEMPLATE_FILE_S3_BUCKET --s3-prefix $OUTPUT_TEMPLATE_FILE_S3_PREFIX --capabilities CAPABILITY_IAM --confirm-changeset --parameter-overrides $(cat $CFN_PARAM_FILE)  


# action: manually configure s3 as event source 
# variables used inside s3_notification_config
export ARN=$(aws cloudformation --region $REGION describe-stacks --stack-name $STACK_NAME --query "Stacks[0].Outputs[?OutputKey=='MoveNewAccessLogsFnOutput'].OutputValue" --output text)

aws lambda add-permission --function-name $ARN --statement-id alb_bucket_enable_notification --action "lambda:InvokeFunction" --principal s3.amazonaws.com --source-arn "arn:aws:s3:::$SourceS3Bucket" --source-account $ACCOUNT --region $REGION



# # aws s3api put-bucket-notification-configuration --bucket $SourceS3Bucket --notification-configuration file://s3_notification_config.json
# sed -e "s/{{ARN}}/$ARN/1" -e "s/{{SourceS3Prefix}}/$SourceS3Prefix/1" s3_notification_config_template.json > s3_notification_config_$ACCOUNT_NAME.json

aws s3api put-bucket-notification-configuration \
--bucket $SourceS3Bucket \
--notification-configuration '
{
  "LambdaFunctionConfigurations": [
    {
      "Id": "alb_log_movement_trigger_notification",
      "LambdaFunctionArn": "'$ARN'",
      "Events": ["s3:ObjectCreated:*"],
      "Filter": {
        "Key": {
          "FilterRules": [
            {
              "Name": "prefix",
              "Value": "'$SourceS3Prefix'"
            }
          ]
        }
      }
    }
  ]
}
'



exit

# action: delete stack
aws cloudformation delete-stack --stack-name $STACK_NAME --region $REGION

# the stack-delete wouln't detete what we have put with `s3api put-bucket-notification-configuration` and `aws lambda add-permission `
# however it gets eventually deleted with the function gets deleted??


