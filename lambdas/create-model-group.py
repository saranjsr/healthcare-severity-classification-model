import boto3

def lambda_handler(event, context):
    sagemaker_client = boto3.client("sagemaker")
    model_package_group_name = event["model_package_group_name"]
    
    # Check if Model Package Group exists
    existing_groups = sagemaker_client.list_model_package_groups()
    group_names = [group["ModelPackageGroupName"] for group in existing_groups["ModelPackageGroupSummaryList"]]

    if model_package_group_name not in group_names:
        print(f"Creating Model Package Group: {model_package_group_name}")
        sagemaker_client.create_model_package_group(
            ModelPackageGroupName=model_package_group_name,
            ModelPackageGroupDescription="Automatically created Model Package Group for Severity Classification."
        )
    else:
        print(f"Model Package Group '{model_package_group_name}' already exists.")
    
    return {"status": "Success"}
