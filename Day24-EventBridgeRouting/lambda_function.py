import json
def lambda_handler(event,context):
    print("Event Bridge Matched Rule Triggered Lambda!")
    detail = event.get("detail",{})
    print(f"Processed High-Value Order:{json.dumps(detail)}")


    return{
        "statusCode":200,
        "body": json.dumps({"status","processed","order",detail})
    }