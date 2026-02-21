import json
import boto3

eventbridge = boto3.client("events")

def lambda_handler(event, context):
    try:
        print(f"Received SNS Event: {event}")
        
        # Extract SNS message details
        sns_message = event["Records"][0]["Sns"]
        message = sns_message["Message"]
        topic_arn = sns_message["TopicArn"]

        # Publish event to EventBridge with consistent source
        response = eventbridge.put_events(
            Entries=[
                {
                    "Source": "custom.sns", 
                    "DetailType": "SNS Notification",
                    "Detail": json.dumps({"topicArn": topic_arn, "message": message}),
                    "EventBusName": "default"
                }
            ]
        )

        print(f"EventBridge Response: {response}")

    except Exception as e:
        print(f"Error: {str(e)}")
        raise 

