import json
import os
import boto3

ssm_client = boto3.client('ssm')

def lambda_handler (event, context):
    print("Interception Request.... Initializing dynamic lookup sequance .")

    parameter_path = os.environ.get("CONFIG_PARAm_PATH")
    
    try:

        
        response = ssm_client.get_parameter(
            Name =parameter_path,
            WithDecrytion= True
        )
        retrieved_secret = response['Parameter']['Value']
        print("SSM Secure Parameter Successfully Intercepted and Loaded into runtime Memory")

    except Exception as e:
        print ("Cryptographic/Parameter Retrival Failue: {str(e)}")
        retrieved_secret = "Access Denied / Config Lookup Failure"

    return {
        'statusCode' : 200,
        'headers' : {'Content-Type': 'application/json'},
        'body' : json.dumps({
            'status': 'authorized',
            'configuration_message' : 'Secrets Decoupled Successfully',
            'secret_value': retrieved_secret
        })
    }