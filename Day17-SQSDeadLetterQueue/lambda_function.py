import json

def lambda_handler(event, context):
    print("Intercepted incoming asynchronous SQS batch payload....")

    for record in event.get('Records', []):
        body = record.get ('body', '')
        print (f"Processing message content: {body}")


        if "fail" in body.lower():
            print("CRITICAL: Malformed payload detected! Throwing Application processing crash...")
            raise ValueError("Simulated Data Processing Exception")

        print("Message Evaluated Successfully!")

    return {
        'statusCode' : 200,
        'body' : json.dumps('Batch block process complete..')
    }