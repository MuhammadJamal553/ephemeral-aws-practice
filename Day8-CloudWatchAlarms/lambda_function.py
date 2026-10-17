import json


def lambda_handler (event, context):
    print("Intercepted monitoring test connection trigger")


    query_params = event.get('queryStringParameters') or {}

    if query_params.get('trigger_fail') == 'true':
        print("CRITICAL : Intentionally executing system function failure for testing!")
        raise RuntimeError("Simulated System Core Execution Failure.")

    return {
        'statusCode' : 200,
        'headers' : {'Content-Type': 'application/json'},
        'body' : json.dumps({'status':'healthy','message':'Monitoring Metrics streaming successfully.'})
    }