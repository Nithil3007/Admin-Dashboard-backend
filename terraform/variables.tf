variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-2"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "admin-dashboard-backend"
}

# GitHub Configuration
variable "github_repository_url" {
  description = "GitHub repository URL (e.g., https://github.com/username/repo)"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch to deploy"
  type        = string
  default     = "main"
}

variable "github_connection_name" {
  description = "Name of existing GitHub connection (if using existing)"
  type        = string
  default     = ""
}

variable "use_existing_github_connection" {
  description = "Use an existing GitHub connection instead of creating a new one"
  type        = bool
  default     = false
}

variable "build_command" {
  description = "Build command for the application"
  type        = string
  default     = "pip install -r requirements.txt"
}

variable "start_command" {
  description = "Start command for the application"
  type        = string
  default     = "uvicorn main:app --host 0.0.0.0 --port 8080"
}

# App Runner Configuration
variable "cpu" {
  description = "CPU units for App Runner (256, 512, 1024, 2048, 4096)"
  type        = string
  default     = "1024"
}

variable "memory" {
  description = "Memory for App Runner (512, 1024, 2048, 3072, 4096, 6144, 8192, 10240, 12288)"
  type        = string
  default     = "2048"
}

variable "min_instances" {
  description = "Minimum number of instances"
  type        = number
  default     = 1
}

variable "max_instances" {
  description = "Maximum number of instances"
  type        = number
  default     = 5
}

variable "max_concurrency" {
  description = "Maximum concurrent requests per instance"
  type        = number
  default     = 100
}

variable "auto_deployments_enabled" {
  description = "Enable automatic deployments when new image is pushed"
  type        = bool
  default     = true
}

# Database Configuration
variable "db_host" {
  description = "Database host"
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = ""
}

variable "db_user" {
  description = "Database user"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  default     = ""
  sensitive   = true
}

variable "db_port" {
  description = "Database port"
  type        = string
  default     = "5432"
}

# Secrets Manager (Optional)
variable "enable_secrets_manager" {
  description = "Use AWS Secrets Manager for sensitive data"
  type        = bool
  default     = false
}

variable "db_password_secret_arn" {
  description = "ARN of the secret containing database password"
  type        = string
  default     = ""
}

# VPC Configuration (Optional - for private RDS)
variable "enable_vpc_connector" {
  description = "Enable VPC connector for private database access"
  type        = bool
  default     = false
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for VPC connector"
  type        = list(string)
  default     = []
}

variable "security_group_ids" {
  description = "List of security group IDs for VPC connector"
  type        = list(string)
  default     = []
}

# Custom Domain (Optional)
variable "custom_domain" {
  description = "Custom domain name for the App Runner service"
  type        = string
  default     = ""
}
