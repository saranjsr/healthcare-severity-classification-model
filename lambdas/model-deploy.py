import boto3
import time
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"Event {event}..")
    sm_client = boto3.client('sagemaker', region_name=event['region'])

    # Verify model is approved
    model_package = sm_client.describe_model_package(
        ModelPackageName=event['model_package_arn']
    )
    
    if model_package['ModelApprovalStatus'] != "Approved":
        raise ValueError("Model package not approved. Current status: " + 
                        model_package['ModelApprovalStatus'])
    
    # Create model name with timestamp
    model_name = f"{event['endpoint_name']}-model-{int(time.time())}"
    
    # Create model
    sm_client.create_model(
        ModelName=model_name,
        ExecutionRoleArn=event['role_arn'],
        Containers=[{
            'ModelPackageName': event['model_package_arn']
        }]
    )

    # Create endpoint config
    endpoint_config_name = f"{event['endpoint_name']}-config-{int(time.time())}"
    sm_client.create_endpoint_config(
        EndpointConfigName=endpoint_config_name,
        ProductionVariants=[{
            'VariantName': 'primary',
            'ModelName': model_name,
            'InstanceType': event['instance_type'],
            'InitialInstanceCount': event['initial_instance_count']
        }]
    )

    # Update or create endpoint
    try:
        sm_client.update_endpoint(
            EndpointName=event['endpoint_name'],
            EndpointConfigName=endpoint_config_name
        )
    except sm_client.exceptions.ClientError as e:
        if "Could not find endpoint" in str(e):
            sm_client.create_endpoint(
                EndpointName=event['endpoint_name'],
                EndpointConfigName=endpoint_config_name
            )
        else:
            raise e

    return {
        'statusCode': 200,
        'body': f"Deployed model {model_name} to endpoint {event['endpoint_name']}"
    }