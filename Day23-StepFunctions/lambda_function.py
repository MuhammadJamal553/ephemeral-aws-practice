import json
def lambda_handler(event, context):
    status= event.get("status","UNKNOWN")
    print(f"Step Function Triggered Lambda With status {status}")

    return {
        "processed"     : True,
        "order_status"  : status,
        "message"       : "Workflow Step Validated Successfully!"
    }