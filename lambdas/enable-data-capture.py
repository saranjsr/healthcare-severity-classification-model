import boto3
import json
import logging
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sagemaker_client = boto3.client("sagemaker")

def wait_for_endpoint(endpoint_name, max_retries=30, sleep_time=10):
    """
    Wait until the endpoint is fully deployed before enabling data capture.
    """
    for _ in range(max_retries):
        response = sagemaker_client.describe_endpoint(EndpointName=endpoint_name)
        status = response["EndpointStatus"]
        
        if status == "InService":
            print(f"Endpoint {endpoint_name} is ready.")
            return True
        
        print(f"Waiting for endpoint {endpoint_name} to be InService... Current status: {status}")
        time.sleep(sleep_time)

    raise Exception(f"Timeout: Endpoint {endpoint_name} did not reach InService state.")

def lambda_handler(event, context):
    logger.info(f"Event .. {event}")
    try:
        endpoint_name = event["endpoint_name"]
        
        data_capture_config = json.loads(event["data_capture_config"])

        wait_for_endpoint(endpoint_name)

        # Get the existing endpoint configuration
        endpoint_desc = sagemaker_client.describe_endpoint(EndpointName=endpoint_name)
        existing_config_name = endpoint_desc["EndpointConfigName"]

        # Fetch the current configuration details
        existing_config = sagemaker_client.describe_endpoint_config(EndpointConfigName=existing_config_name)

        # Create a new endpoint configuration with data capture enabled
        new_config_name = f"{endpoint_name}-data-capture-{int(context.aws_request_id[:8], 16)}"

        response = sagemaker_client.create_endpoint_config(
            EndpointConfigName=new_config_name,
            ProductionVariants=existing_config["ProductionVariants"],
            DataCaptureConfig=data_capture_config 
        )

        # Update the endpoint with the new configuration
        sagemaker_client.update_endpoint(
            EndpointName=endpoint_name,
            EndpointConfigName=new_config_name
        )

        return {
            "statusCode": 200,
            "body": json.dumps(f"Data capture enabled for endpoint: {endpoint_name}")
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps(f"Error enabling data capture: {str(e)}")
        }
