terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# GitHub Connection for App Runner
# Note: You need to create this connection manually in AWS Console first
# or use the AWS CLI to authorize GitHub access
data "aws_apprunner_connection" "github" {
  count = var.use_existing_github_connection ? 1 : 0
  name  = var.github_connection_name
}

resource "aws_apprunner_connection" "github" {
  count             = var.use_existing_github_connection ? 0 : 1
  connection_name   = "${var.app_name}-github-connection"
  provider_type     = "GITHUB"

  tags = {
    Name        = "${var.app_name}-github-connection"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Note: After creating the connection, you must manually authorize it in the AWS Console
# Go to App Runner > GitHub connections and complete the OAuth flow

# IAM Role for App Runner Instance
resource "aws_iam_role" "apprunner_instance_role" {
  name = "${var.app_name}-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "tasks.apprunner.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.app_name}-instance-role"
    Environment = var.environment
  }
}

# IAM Role for App Runner Build (GitHub source)
resource "aws_iam_role" "apprunner_build_role" {
  name = "${var.app_name}-build-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "build.apprunner.amazonaws.com"
      }
    }]
  })

  tags = {
    Name        = "${var.app_name}-build-role"
    Environment = var.environment
  }
}

# Attach managed policy for App Runner build
resource "aws_iam_role_policy_attachment" "apprunner_build" {
  role       = aws_iam_role.apprunner_build_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

# Optional: VPC Connector for private RDS access
resource "aws_apprunner_vpc_connector" "main" {
  count = var.enable_vpc_connector ? 1 : 0

  vpc_connector_name = "${var.app_name}-vpc-connector"
  subnets            = var.private_subnet_ids
  security_groups    = var.security_group_ids

  tags = {
    Name        = "${var.app_name}-vpc-connector"
    Environment = var.environment
  }
}

# App Runner Auto Scaling Configuration
resource "aws_apprunner_auto_scaling_configuration_version" "main" {
  auto_scaling_configuration_name = "${var.app_name}-autoscaling"
  
  max_concurrency = var.max_concurrency
  max_size        = var.max_instances
  min_size        = var.min_instances

  tags = {
    Name        = "${var.app_name}-autoscaling"
    Environment = var.environment
  }
}

# App Runner Service
resource "aws_apprunner_service" "admin_dashboard_backend" {
  service_name = var.app_name

  source_configuration {
    authentication_configuration {
      connection_arn = var.use_existing_github_connection ? data.aws_apprunner_connection.github[0].arn : aws_apprunner_connection.github[0].arn
    }

    code_repository {
      repository_url = var.github_repository_url
      
      source_code_version {
        type  = "BRANCH"
        value = var.github_branch
      }

      code_configuration {
        configuration_source = "API"  # Use API configuration instead of apprunner.yaml
        
        code_configuration_values {
          runtime = "PYTHON_3"
          
          build_command = var.build_command
          start_command = var.start_command
          port          = "8080"
          
          runtime_environment_variables = merge(
            {
              DB_HOST     = var.db_host
              DB_NAME     = var.db_name
              DB_USER     = var.db_user
              DB_PORT     = var.db_port
              ENVIRONMENT = var.environment
            },
            var.enable_secrets_manager ? {} : {
              DB_PASSWORD = var.db_password
            }
          )

          runtime_environment_secrets = var.enable_secrets_manager ? {
            DB_PASSWORD = var.db_password_secret_arn
          } : {}
        }
      }
    }

    auto_deployments_enabled = var.auto_deployments_enabled
  }

  instance_configuration {
    cpu               = var.cpu
    memory            = var.memory
    instance_role_arn = aws_iam_role.apprunner_instance_role.arn
  }

  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.main.arn

  health_check_configuration {
    protocol            = "HTTP"
    path                = "/"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 5
  }

  dynamic "network_configuration" {
    for_each = var.enable_vpc_connector ? [1] : []
    content {
      egress_configuration {
        egress_type       = "VPC"
        vpc_connector_arn = aws_apprunner_vpc_connector.main[0].arn
      }
    }
  }

  tags = {
    Name        = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.apprunner_build
  ]
}

# Custom Domain (Optional)
resource "aws_apprunner_custom_domain_association" "main" {
  count = var.custom_domain != "" ? 1 : 0

  domain_name = var.custom_domain
  service_arn = aws_apprunner_service.admin_dashboard_backend.arn
}
