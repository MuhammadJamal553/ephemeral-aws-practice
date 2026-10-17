import json
import os
import boto3

dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('DYNAMODB_TABLE')
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    try:
        response = table.update_item(
            Key={'MetricName': 'VisitorCount'},
            UpdateExpression="ADD #count_val :incr",
            ExpressionAttributeNames={'#count_val': 'Count'},
            ExpressionAttributeValues={':incr': 1},
            ReturnValues="UPDATED_NEW"
        )
        current_count = int(response['Attributes']['Count'])
    except Exception as e:
        print(f"Error: {str(e)}")
        current_count = 0
        
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps({'status': 'automated', 'count': current_count})
    }