
resource "aws_s3_bucket" "pipeline_bucket" {
  bucket = var.tf_s3_pipeline
   force_destroy = true

  tags = {
    Name        = "SageMaker Pipeline Bucket"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_ownership_controls" "pipeline_bucket" {
  bucket = aws_s3_bucket.pipeline_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "pipeline_bucket_versioning" {
  bucket = aws_s3_bucket.pipeline_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "s3_pipeline_bucket_block" {
  bucket = aws_s3_bucket.pipeline_bucket.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
  
}

resource "aws_s3_bucket_server_side_encryption_configuration" "pipeline_bucket_encryption" {
  bucket = aws_s3_bucket.pipeline_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "s3_pipeline_bucket_policy" {
  bucket = aws_s3_bucket.pipeline_bucket.id

  policy =  <<EOF
  {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ForceSSLOnlyAccess",
            "Effect": "Deny",
            "Principal": {
                "AWS": "*"
            },
            "Action": "s3:*",
            "Resource": "${aws_s3_bucket.pipeline_bucket.arn}/*",
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
  }
  EOF
}
  

resource "aws_s3_object" "healthcare-data" {
  bucket = aws_s3_bucket.pipeline_bucket.id
  key    = "healthcare-data/raw-data/healthcare_data.csv"
  source = "dataset/healthcare_data.csv"
}

resource "aws_s3_object" "preprocessing_script" {
  bucket = aws_s3_bucket.pipeline_bucket.id
  key    = "healthcare-data/scripts/preprocessing.py"
  source = "scripts/preprocessing.py" 
}

resource "aws_s3_object" "train_script" {
  bucket = aws_s3_bucket.pipeline_bucket.id
  key    = "healthcare-data/scripts/train.py"
  source = "scripts/train.py"
}

resource "aws_s3_object" "evaluation_script" {
  bucket = aws_s3_bucket.pipeline_bucket.id
  key    = "healthcare-data/scripts/evaluation.py"
  source = "scripts/evaluation.py"
}

resource "aws_s3_object" "baseline_script" {
  bucket = aws_s3_bucket.pipeline_bucket.id
  key    = "healthcare-data/scripts/generate_baseline.py"
  source = "scripts/generate_baseline.py"
}

resource "aws_s3_object" "monitoring_script" {
  bucket = aws_s3_bucket.pipeline_bucket.id
  key    = "healthcare-data/scripts/monitoring.py"
  source = "scripts/monitoring.py"
}

resource "aws_s3_object" "traintar_script" {
  bucket = aws_s3_bucket.pipeline_bucket.id
  key    = "healthcare-data/scripts/trainsourcedir.tar.gz"
  source = "scripts/trainsourcedir.tar.gz"
}

