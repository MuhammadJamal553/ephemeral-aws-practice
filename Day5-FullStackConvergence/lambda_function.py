import json
import os
import boto3

sns_client = boto3.client('sns')

def lambda_handler(event,context):
    print("Edge Network intercepted Initiallizing notification broadcast...")
    topic_arn = os.environ.get('SNS_TOPIC_ARN')

    try:
        sns_client.publish(
            TopicArn = topic_arn,
            subject  = "Production Arlert: Gloval Resume Visitor Dectected!",
            Message  = "System Notice: \n\nA User has successfully loaded your full stack web application via the CloudFront CDN Edge framework."
        )
    except Exception as e:
        print(f"SNS Broadcast Failed: {str(e)}")
    return {
        'statuscode': 200,
        'header':{
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({'status':'logged','message':'Metric tracked!'})
    }