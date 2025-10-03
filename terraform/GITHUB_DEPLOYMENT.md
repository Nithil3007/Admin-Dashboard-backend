# GitHub-Based Deployment Architecture

## Overview

This Terraform configuration deploys your FastAPI application to AWS App Runner using **GitHub as the source**, eliminating the need for ECR (Elastic Container Registry).

## How It Works

```
GitHub Repository → AWS App Runner → Your Application
     ↓                    ↓
  git push          Auto-builds & deploys
```

### Deployment Flow

1. **Push to GitHub**: You push code to your GitHub repository
2. **App Runner Detects**: App Runner monitors your configured branch
3. **Auto Build**: App Runner builds your application using Python runtime
4. **Deploy**: New version is automatically deployed
5. **Scale**: Auto-scales based on traffic (1-5 instances)

## Architecture Components

### 1. GitHub Connection
- **Resource**: `aws_apprunner_connection`
- **Purpose**: OAuth connection between AWS and GitHub
- **Status**: Must be manually authorized after creation
- **Reusable**: Can be shared across multiple App Runner services

### 2. App Runner Service
- **Source**: GitHub repository (code_repository)
- **Runtime**: Python 3
- **Build**: Runs `pip install -r requirements.txt`
- **Start**: Runs `uvicorn main:app --host 0.0.0.0 --port 8080`
- **Auto-deploy**: Enabled by default

### 3. IAM Roles
- **Instance Role**: Permissions for your running application
- **Build Role**: Permissions for building from source

### 4. Auto Scaling
- **Min**: 1 instance
- **Max**: 5 instances
- **Concurrency**: 100 requests per instance
- **Automatic**: Scales based on traffic

### 5. VPC Connector (Optional)
- **Purpose**: Access private RDS databases
- **Required**: Only if database is in private subnet
- **Configuration**: Specify subnets and security groups

## Key Differences from ECR Deployment

| Feature | ECR Deployment | GitHub Deployment |
|---------|---------------|-------------------|
| **Source** | Docker image in ECR | Code in GitHub |
| **Build** | Local Docker build | App Runner builds |
| **Push** | Docker push to ECR | Git push to GitHub |
| **Cost** | ECR storage fees | No ECR costs |
| **Complexity** | More steps | Simpler |
| **Control** | Full Docker control | Managed build |
| **Speed** | Faster (pre-built) | Slightly slower (builds on deploy) |

## Configuration Files

### Required in Repository

1. **requirements.txt** - Python dependencies
   ```
   fastapi
   uvicorn[standard]
   psycopg2-binary
   pydantic
   ```

2. **main.py** - Your FastAPI application
   - Must expose app on port 8080
   - Should read environment variables

### Terraform Files

1. **main.tf** - Infrastructure definition
2. **variables.tf** - Configurable parameters
3. **outputs.tf** - Service information
4. **terraform.tfvars** - Your specific values

## Environment Variables

Automatically injected into your application:

```python
import os

db_host = os.getenv("DB_HOST")
db_name = os.getenv("DB_NAME")
db_user = os.getenv("DB_USER")
db_password = os.getenv("DB_PASSWORD")
db_port = os.getenv("DB_PORT")
environment = os.getenv("ENVIRONMENT")
```

## GitHub Connection Authorization

### Why Manual Authorization?

AWS requires explicit user consent to access GitHub repositories for security reasons.

### Authorization Steps

1. **Create Connection** (via Terraform)
   ```bash
   terraform apply
   ```

2. **Authorize in Console**
   - Go to: https://console.aws.amazon.com/apprunner/home#/connections
   - Find: `admin-dashboard-backend-github-connection`
   - Click: "Complete handshake"
   - Authenticate with GitHub
   - Grant repository access

3. **Complete Deployment**
   ```bash
   terraform apply
   ```

### Alternative: Pre-create Connection

```bash
# Create connection manually
aws apprunner create-connection \
  --connection-name my-github-connection \
  --provider-type GITHUB \
  --region us-east-2

# Authorize in console

# Use in Terraform
use_existing_github_connection = true
github_connection_name = "my-github-connection"
```

## Build Process

### What Happens During Build

1. **Clone**: App Runner clones your GitHub repository
2. **Install**: Runs `pip install -r requirements.txt`
3. **Package**: Prepares application for deployment
4. **Deploy**: Starts application with start command
5. **Health Check**: Verifies application is running

### Build Logs

View in CloudWatch Logs:
- Log Group: `/aws/apprunner/<service-name>/service`

### Customizing Build

In `terraform.tfvars`:
```hcl
build_command = "pip install -r requirements.txt && python setup.py"
start_command = "gunicorn main:app -w 4 -k uvicorn.workers.UvicornWorker --bind 0.0.0.0:8080"
```

## Auto-Deployment

### How It Works

1. You push to configured branch (e.g., `main`)
2. App Runner detects the change
3. Triggers automatic build and deployment
4. Zero-downtime rolling update

### Disable Auto-Deploy

In `terraform.tfvars`:
```hcl
auto_deployments_enabled = false
```

Then manually trigger:
```bash
aws apprunner start-deployment \
  --service-arn <service-arn> \
  --region us-east-2
```

## Security Best Practices

### 1. Use Secrets Manager
```hcl
enable_secrets_manager = true
db_password_secret_arn = "arn:aws:secretsmanager:..."
```

### 2. Private Database Access
```hcl
enable_vpc_connector = true
private_subnet_ids = ["subnet-xxx", "subnet-yyy"]
security_group_ids = ["sg-xxx"]
```

### 3. Least Privilege IAM
- Instance role has minimal permissions
- Build role only has build permissions

### 4. HTTPS Only
- App Runner provides automatic HTTPS
- No HTTP endpoint exposed

## Monitoring

### CloudWatch Metrics
- Request count
- Response time
- Active instances
- CPU/Memory utilization

### CloudWatch Logs
- Application logs: `/aws/apprunner/<service>/application`
- Service logs: `/aws/apprunner/<service>/service`

### Health Checks
- Path: `/`
- Interval: 10 seconds
- Timeout: 5 seconds
- Healthy threshold: 1
- Unhealthy threshold: 5

## Cost Optimization

### Tips to Reduce Costs

1. **Right-size instances**
   - Start with 1 vCPU, 2GB RAM
   - Monitor and adjust

2. **Optimize min instances**
   - Use 1 for development
   - Use 2+ for production (high availability)

3. **Set appropriate max instances**
   - Don't over-provision
   - Monitor actual usage

4. **Use auto-pause** (if available)
   - Pause during low traffic periods

## Troubleshooting

### Build Failures

**Check**: CloudWatch Logs → Service logs
**Common Issues**:
- Missing dependencies in `requirements.txt`
- Python version incompatibility
- Syntax errors in code

### Connection Issues

**Check**: GitHub connection status
**Fix**: Re-authorize in AWS Console

### Runtime Errors

**Check**: CloudWatch Logs → Application logs
**Common Issues**:
- Environment variables not set
- Database connection failures
- Port mismatch (must be 8080)

### Database Connection

**Check**: VPC connector configuration
**Fix**: 
- Enable VPC connector if RDS is private
- Verify security group rules
- Check database credentials

## Comparison: Configuration Sources

### API Configuration (Current)
```hcl
code_configuration {
  configuration_source = "API"
  code_configuration_values {
    runtime = "PYTHON_3"
    build_command = "..."
    start_command = "..."
  }
}
```

**Pros**: Centralized in Terraform, version controlled
**Cons**: Requires Terraform to change

### Repository Configuration (Alternative)
```hcl
code_configuration {
  configuration_source = "REPOSITORY"
}
```

Uses `apprunner.yaml` in repository:
```yaml
version: 1.0
runtime: python3
build:
  commands:
    build:
      - pip install -r requirements.txt
run:
  command: uvicorn main:app --host 0.0.0.0 --port 8080
```

**Pros**: Developers can change without Terraform
**Cons**: Less centralized control

## Next Steps

1. ✅ Push code to GitHub
2. ✅ Configure `terraform.tfvars`
3. ✅ Run `terraform apply`
4. ✅ Authorize GitHub connection
5. ✅ Run `terraform apply` again
6. ✅ Access your application
7. ✅ Push updates to auto-deploy

## Resources

- [AWS App Runner Documentation](https://docs.aws.amazon.com/apprunner/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Integration Guide](https://docs.aws.amazon.com/apprunner/latest/dg/manage-connections.html)
