import json
import os
import boto3


# Initialize the AWS SDK clients outside the handler execution loop (Best Practice)
sns_client = boto3.client('sns')

def lambda_handler(event,context):
    print("API Trigger intercepted.Dispatching SNS push trasmission alert....")
    
    # Grab the target Topic ARN loaded dynamically from our environment variables
    topic_arn = os.environ.get('SNS_Topic_ARN')

    try:
        # Publish the event alert directly to our decoupled notification bus
        response = sns_client.publish(
            Topic_Arn = topic_arn,
            Subject = "Alert: New Portfolio Visitor Activity Captured",
            Message = "System Event Notice:\n\nA Live Connection request has successfully hit your serverless AWS backend framework"
        )
        print(f"SNS Massage published Successfully. MessageId: {response['MassageId']}")

    except Exception as e:
        print(f"Critical Transformation Failure {str(e)}")

    return {
        'statuscode' : 200,
        'hearders' : {
            'Content-Type' : 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps ({'status':'alert_dispatched','massage': 'Visitor rigistered successfully!'})
    }