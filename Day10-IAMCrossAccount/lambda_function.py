from botocore import credentials
import json
import os
import boto3

sts_client = boto3.client("sts")

def lambda_handler (event, context):
    print ("Intercepting Execution Pipeline.... Launching dynamic cross Account role assumption sequance.")
    # Grab today's target assumed role ARN and S3 bucket indicators passed via environment variables
    target_role_arn     = os.environ.get('TARGET_ROLE_ARN')
    target_bucket_name  = os.environ.get('TARGET_BUCKET_NAME')

    try:
        # 1. Call AWS Security Token Service to assume the higher privileged role identity
        print (f"Requesting temprory cross-Account credentials for: {target_role_arn}.")
        assume_role_object = sts_client.assume_role(
            RoleArn=target_role_arn,
            RoleSessionName="JamalMarathonCrossAccountSession"
        )

        # 2. Extract the temporary cryptographic credential keys from the STS response payload
        credentials =assume_role_object['Credentials']

        # 3. Spin up an isolated S3 client using exclusively the short-lived session token variables
        s3_assume_client = boto3.client(
            's3',
            aws_access_key_id= credentials['AccessKeyId'],
            aws_secret_access_key=credentials['SecretAccessKey'],
            aws_session_token=credentials['SessionToken']
        )
        print("STS Session token applied successfully. Testing Access Parameters Against target Storage origin...")

        bucket_loction = s3_assume_client.get_bucket_location(Bucket=target_bucket_name)
        status_message  = f"Success! Securely assumed role token granted read access. bucket region: {bucket_loction.get('LocationContraint') or 'us-east-1'}"
        

    except Exception as e:
        print(f"STS Cryptographic Delegation Failure: {str(e)}")
        status_message = f"AccessDecied: Lambda Execution role was blocked from assuming target role/reading bucket. Details: {str(e)}"

    return {
        'statusCode' : 200,
        'headers' : {'Content-Type': 'application/json'},
        'body' : json.dumps({
            'status': 'evaluation_complete',
            'sts_delegation_result' : status_message
         }) 
    }