variable "environment" {
    type = string
    default = "Dev"
}

variable "vpc_name" {
    type = string
    default = "sagemaker-vpc-tf"
}

variable "tf_s3_pipeline" {
    type = string
    default = "healthcare-pipeline-tf"
}

variable "healthcare_dataset_bucket_name" {
    type = string
    default = "severity-healthcare-dataset-latest"
}

variable "sagemaker_pipeline_name" {
    type = string
    default = "severity-classification-pipeline-tf"
}

variable "sagemaker_pipeline_username" {
    type = string
    default = "saran-tf"
}

variable "sagemaker_domain_name" {
        type = string
        default = "healthcare-domain-tf"
}

variable "sagemaker_role_name" {
    type = string
    default = "sagemaker-ml-execution-role-1-tf"
  
}