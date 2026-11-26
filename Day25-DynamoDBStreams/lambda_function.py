import json


def lambda_handler(event, context):
    records = event.get("Records", [])
    print(f"Received batch of {len(records)} DynamoDB Stream records.")

    for record in records:
        event_name = record.get("eventName")
        dynamodb_data = record.get("dynamodb", {})

        print(f"Event Type: {event_name}")

        if "NewImage" in dynamodb_data:
            print(f"New Item Image: {json.dumps(dynamodb_data['NewImage'])}")
        if "OldImage" in dynamodb_data:
            print(f"Old Item Image: {json.dumps(dynamodb_data['OldImage'])}")

    return {"statusCode": 200, "body": "Stream records processed successfully"}
