#!/bin/bash
set -x #echo on
set -v # verbose. include comments.


ACTION=$1
REGION=ap-southeast-2

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



source env/$ACCOUNT_NAME.dbvars 
# AthenaTableExternalLocation=s3://$TargetS3Bucket/$TargetS3Prefix/

QUERY_STRING_CREATE_DDL=$(sed -e "s/{{DB_NAME}}/$AthenaDatabase/g" -e "s/{{TABLE_NAME}}/$AthenaTableName/g" -e "s/{{TargetS3Bucket}}/$TargetS3Bucket/g" -e "s/{{TargetS3Prefix}}/$TargetS3Prefix/g" athena-template.ddl)
RESULT_CONFIGURATION="OutputLocation=s3://$AthenaQueryResultBucket/$AthenaQueryResultPrefix"
QUERY_EXECUTION_CONTEXT="Database=$AthenaDatabase"



if [ ${ACTION} = 'create-db' ]; then
    echo "creating db"
    aws athena start-query-execution \
    --query-string "CREATE DATABASE IF NOT EXISTS $AthenaDatabase;" \
    --result-configuration $RESULT_CONFIGURATION \
    --region $REGION
    # --query-execution-context $QUERY_EXECUTION_CONTEXT

elif [ ${ACTION} = 'drop-tbl' ]; then
    echo "dropping table"
    aws athena start-query-execution \
    --query-string "DROP TABLE IF EXISTS $AthenaDatabase.$AthenaTableName;" \
    --result-configuration $RESULT_CONFIGURATION \
    --region $REGION

    # --query-execution-context $QUERY_EXECUTION_CONTEXT

elif [ ${ACTION} = 'create-tbl' ]; then
    echo "creating table"
    echo $QUERY_STRING_CREATE_DDL
    aws athena start-query-execution \
    --query-string "$QUERY_STRING_CREATE_DDL" \
    --result-configuration $RESULT_CONFIGURATION \
    --query-execution-context $QUERY_EXECUTION_CONTEXT \
    --region $REGION

fi
exit

