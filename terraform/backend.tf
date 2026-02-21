terraform {
  backend "s3" {
    bucket         = "sagemaker-terraform-state-bucket"
    key            = "terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    use_lockfile   = true
  }
}
