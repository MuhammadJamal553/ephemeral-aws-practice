import json
import os
import boto3

dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('DYNAMODB_TABLE')
table = dynamodb.Table(table_name)

def lambda_handler (event,context):
    print("Intercepted Porfolio session event tracking trigger...")

    try:
        response =table.update_item(
            Key ={'MetricName': 'VisitorCount'},
            UpdateExpression = "ADD #count_val :incr",
            ExpressionAttributeNames = {'#count_val': 'Count'},
            ExpressionAttributeValues = {':incr': 1},
            ReturnValues = "UPDATED_NEW"
        )


        current_count = int(response['Attributes']['Count'])
        print(f"Metrics synchronization complete. Updated Database count: {current_count}")

    except Exception as e:
        print(f"Database Integration Failure {str(e)}")
        current_count = 0

    return {
        'statusCode' : 200,
        'headers': {
            'content-type': 'application/json',
            'Access-Control-Allow-origin': '*'
        },
        'body' : json.dumps({
            'status' : 'tracked',
            'visitor_count': current_count
        })
    }