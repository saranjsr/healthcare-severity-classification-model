import boto3
import os

aws_region = os.getenv("AWS_REGION")
pipeline_name = os.getenv("SAGEMAKER_PIPELINE_NAME")
print(f"Pipeline name is {pipeline_name}")

sagemaker_client = boto3.client("sagemaker", region_name=aws_region)

def start_pipeline():
    response = sagemaker_client.start_pipeline_execution(PipelineName=pipeline_name)
    execution_arn = response["PipelineExecutionArn"]
    print(f"Pipeline Execution Started: {execution_arn}")
    return execution_arn

if __name__ == "__main__":
    start_pipeline()
