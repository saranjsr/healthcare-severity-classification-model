import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    logger.info(f"Event {event}..")
    sm_client = boto3.client('sagemaker', region_name='eu-north-1')
    model_package_arn = event['model_package_arn']
    
    try:
        # Update approval status
        response = sm_client.update_model_package(
            ModelPackageArn=model_package_arn,
            ModelApprovalStatus="Approved"
        )
        
        # Verify update
        model_package = sm_client.describe_model_package(
            ModelPackageName=model_package_arn
        )
        
        if model_package['ModelApprovalStatus'] != "Approved":
            raise Exception("Approval status update failed")
            
        logger.info(f"Successfully approved: {model_package_arn}")
        return {
            'statusCode': 200,
            'body': f"Approved: {model_package_arn}"
        }
        
    except Exception as e:
        logger.error(f"Approval failed: {str(e)}")
        raise e