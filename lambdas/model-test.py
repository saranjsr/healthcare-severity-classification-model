import boto3
import json
import numpy as np
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

runtime = boto3.client('sagemaker-runtime', region_name='eu-north-1')

def lambda_handler(event, context):
    logger.info(f"Event .. {event}")
    sample_input = event

    # 1. Get raw response
    response = runtime.invoke_endpoint(
        EndpointName='health-severity-endpoint-tf',
        ContentType='text/csv',
        Body=",".join(map(str, sample_input))
    )

    print(response)

    raw_output = response['Body'].read().decode()
    print("Raw Output:", raw_output) 

    try:
        predictions = json.loads(raw_output)
    except json.JSONDecodeError:
        predictions = list(map(float, raw_output.split(',')))

    predicted_class = np.argmax(predictions)
    confidence = predictions[predicted_class]

    return(f"Predicted Class: {predicted_class} (Confidence: {confidence:.2%})")
    
