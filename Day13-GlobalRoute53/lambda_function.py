from requests import status_codes
import json
import os

def lambda_handler (event, context):
    current_aws_region = os.environ.get('AWS_REGION', 'unknown-region')
    print(f"Request Intercept Successfully Handled inside: {current_aws_region}")

    return {
        'statusCode': 200,
        'headers'  : {'Content-Type' : 'application/json'},
        'body'      : json.dumps({
            'status' : 'online',
            'execution_tier' : 'Multi-Region Serverless Grid',
            'active_aws_datacenter_location': current_aws_region,
            'message' : f'Hello From the global Resilient backend running inside {current_aws_region}!'
        })
    }