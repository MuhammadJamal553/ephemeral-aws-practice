import json

def lambda_handler(content,event):
    print("API Trigger Captured Successfully")

    return{
        'statusCode': 200,
        'headers':{
            'Content-Type' : 'application/json',
            'Access-Control-Allow-Origin' : '*'
        },
        'body': json.dumps({
            'status':'success',
            'message': 'Hello From your serverless AWS LAMBDA Backend'
        })
    }