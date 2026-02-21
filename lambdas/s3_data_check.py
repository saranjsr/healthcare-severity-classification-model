import boto3
import json
import os

# Initialize S3 Client
s3_client = boto3.client("s3")

def lambda_handler(event, context):
    try:
        # Extract S3 path from event
        s3_uri = event["s3_path"]
        
        # Parse bucket and prefix
        if not s3_uri.startswith("s3://"):
            return {"statusCode": 400, "body": "Invalid S3 URI format"}

        s3_parts = s3_uri.replace("s3://", "").split("/", 1)
        bucket_name = s3_parts[0]
        prefix = s3_parts[1] if len(s3_parts) > 1 else ""

        # List objects under the given prefix
        response = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=prefix)

        # Check if any objects exist
        data_available = "Contents" in response and len(response["Contents"]) > 0

        return {
            "statusCode": 200,
            "body": json.dumps({"data_available": data_available})
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps(f"Error checking S3 data: {str(e)}")
        }
