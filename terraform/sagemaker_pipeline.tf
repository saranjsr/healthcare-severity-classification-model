# 3. Create an AWS IAM Role for SageMaker
resource "aws_iam_role" "sagemaker_role" {
  name = var.sagemaker_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "sagemaker.amazonaws.com"
        }
      }
    ]
  })
}



resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy_attachment" "sagemaker_s3_access" {
  role       = aws_iam_role.sagemaker_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "sagemaker_canvas" {
  role       = aws_iam_role.sagemaker_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerCanvasFullAccess"
}

resource "aws_iam_role_policy_attachment" "sagemaker_cloudwatch" {
  role       = aws_iam_role.sagemaker_role.id
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy_attachment" "sagemaker_lambda" {
  role       = aws_iam_role.sagemaker_role.id
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
}

resource "aws_iam_policy" "s3_healthcare_bucket_access" {
  name = "s3-healthcare-bucket-access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.pipeline_bucket.bucket}",
          "arn:aws:s3:::${aws_s3_bucket.pipeline_bucket.bucket}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_scoped_access" {
  role       = aws_iam_role.sagemaker_role.id
  policy_arn = aws_iam_policy.s3_healthcare_bucket_access.arn
}

resource "aws_iam_role_policy" "sagemaker_policy" {
  name = "SagemakerUSerPolicytf"
  role = aws_iam_role.sagemaker_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "sagemaker:*",
                "iam:ListEntitiesForPolicy",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "logs:CreateLogGroup"
            ],
            "Resource": "*"
        }
    ]
  })
}

#  Create a SageMaker Domain
resource "aws_sagemaker_domain" "sagemaker_domain" {
  domain_name  = var.sagemaker_domain_name
  auth_mode    = "IAM"
  vpc_id       = aws_vpc.main.id  
  subnet_ids   = [aws_subnet.public_1.id,aws_subnet.public_2.id ]

  app_network_access_type = "VpcOnly"

  default_user_settings {
    execution_role = aws_iam_role.sagemaker_role.arn
    studio_web_portal = "ENABLED"
    auto_mount_home_efs = "Disabled"
    
    jupyter_lab_app_settings {
      default_resource_spec {
        instance_type = "ml.t3.medium"
      }
   }
    sharing_settings {
        notebook_output_option = "Disabled"
    }
  }
  default_space_settings {
    execution_role = aws_iam_role.sagemaker_role.arn
  }
}

#  Create a SageMaker User Profile
resource "aws_sagemaker_user_profile" "sagemaker_user" {
  domain_id = aws_sagemaker_domain.sagemaker_domain.id
  user_profile_name = var.sagemaker_pipeline_username
  user_settings {
    execution_role = aws_iam_role.sagemaker_role.arn

    jupyter_lab_app_settings {
      default_resource_spec {
        instance_type = "ml.t3.medium"
      }
      app_lifecycle_management {
        idle_settings {
          lifecycle_management = "ENABLED"
          idle_timeout_in_minutes = 60
          max_idle_timeout_in_minutes = 120
          min_idle_timeout_in_minutes  = 60
        }
      }
    }
    
    jupyter_server_app_settings {
      default_resource_spec {
        instance_type = "system"
      }
    }
    
    kernel_gateway_app_settings {
      default_resource_spec {
        instance_type = "ml.t3.medium"
      }
    }
    
    # Enable TensorBoard app
    tensor_board_app_settings {
      default_resource_spec {
        instance_type = "ml.t3.medium"
      }
    }
    
    # Enable RStudio
    r_studio_server_pro_app_settings {
      access_status = "ENABLED"
      user_group    = "R_STUDIO_USER"
    }
    
    # sharing_settings {
    #   notebook_output_option = "Allowed"
    #   s3_output_path        = "s3://${aws_s3_bucket.sagemaker_output_bucket.bucket}/user-output/"
    #   s3_kms_key_id         = aws_kms_key.sagemaker_kms_key.arn
    # }
  }
}


# SageMaker Pipeline
resource "aws_sagemaker_pipeline" "severity_pipeline" {
  pipeline_name = var.sagemaker_pipeline_name
  pipeline_display_name = var.sagemaker_pipeline_name
  role_arn       = aws_iam_role.sagemaker_role.arn
  pipeline_definition = file("${path.module}/sagemaker_pipeline_lt.json")
}


