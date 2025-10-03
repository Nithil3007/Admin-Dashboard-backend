# Terraform Configuration for AWS App Runner Deployment

This Terraform configuration deploys the Admin Dashboard Backend FastAPI application to AWS App Runner directly from GitHub.

## Architecture

- **AWS App Runner**: Fully managed container service
- **GitHub Integration**: Direct deployment from GitHub repository
- **Auto Scaling**: Automatic scaling based on traffic (1-5 instances)
- **VPC Connector**: Optional private database access
- **IAM Roles**: Secure access management
- **Auto Deploy**: Automatically deploys on git push

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0 installed
3. **GitHub Repository** with your application code
4. **AWS Account** with necessary permissions

## Quick Start

### 1. Push Code to GitHub

Ensure your application code is in a GitHub repository:

```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/your-username/admin-dashboard-backend.git
git push -u origin main
```

### 2. Configure Variables

Copy the example variables file and update with your values:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your specific configuration:
- **GitHub repository URL** (e.g., `https://github.com/your-username/admin-dashboard-backend`)
- **GitHub branch** (e.g., `main`)
- Database credentials
- AWS region
- App Runner instance size
- VPC settings (if using private RDS)

### 3. Deploy with Terraform

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply configuration
terraform apply
```

### 4. Authorize GitHub Connection

**IMPORTANT**: After the first `terraform apply`, you must authorize the GitHub connection:

1. Go to AWS Console → App Runner → GitHub connections
2. Find the connection named `admin-dashboard-backend-github-connection`
3. Click "Complete handshake" or "Authorize"
4. Authenticate with GitHub and grant permissions
5. Run `terraform apply` again to complete the deployment

Alternatively, you can create the connection manually first and use it:
```bash
# Create connection via AWS CLI
aws apprunner create-connection \
  --connection-name my-github-connection \
  --provider-type GITHUB \
  --region us-east-2

# Then authorize it in the console and update terraform.tfvars:
use_existing_github_connection = true
github_connection_name = "my-github-connection"
```

### 5. Access Your Application

```bash
# Get the App Runner service URL
terraform output apprunner_service_url
```

Your application will be available at the provided URL (e.g., `https://xxxxx.us-east-2.awsapprunner.com`)

### 6. Automatic Deployments

Once set up, any push to your configured branch will automatically trigger a new deployment! 🚀

## Configuration Options

### Instance Sizing

| CPU  | Memory | Use Case |
|------|--------|----------|
| 256  | 512    | Development/Testing |
| 512  | 1024   | Light production |
| 1024 | 2048   | **Recommended** |
| 2048 | 4096   | High traffic |
| 4096 | 12288  | Very high traffic |

### Auto Scaling

- **min_instances**: Minimum running instances (default: 1)
- **max_instances**: Maximum instances (default: 5)
- **max_concurrency**: Concurrent requests per instance (default: 100)

### VPC Configuration

Enable VPC connector if your RDS database is in a private subnet:

```hcl
enable_vpc_connector = true
private_subnet_ids   = ["subnet-xxx", "subnet-yyy"]
security_group_ids   = ["sg-xxx"]
```

### Secrets Management

For production, use AWS Secrets Manager:

```hcl
enable_secrets_manager = true
db_password_secret_arn = "arn:aws:secretsmanager:region:account:secret:name"
```

## Environment Variables

The following environment variables are automatically configured:

- `DB_HOST`: Database hostname
- `DB_NAME`: Database name
- `DB_USER`: Database username
- `DB_PASSWORD`: Database password
- `DB_PORT`: Database port
- `ENVIRONMENT`: Environment name (dev/staging/prod)

## Custom Domain

To use a custom domain:

1. Set `custom_domain` in `terraform.tfvars`
2. Apply Terraform configuration
3. Get DNS target: `terraform output custom_domain_dns_target`
4. Create CNAME record in your DNS provider pointing to the DNS target

## Updating the Application

### Automatic Deployment (Default)

If `auto_deployments_enabled = true` (default), simply push to GitHub:

```bash
git add .
git commit -m "Update application"
git push origin main
```

App Runner will automatically detect the changes and deploy the new version!

### Manual Deployment

If you disabled auto-deployments, trigger a deployment manually:

```bash
# Via AWS CLI
aws apprunner start-deployment \
  --service-arn $(terraform output -raw apprunner_service_arn) \
  --region us-east-2

# Or via Terraform (force recreation)
terraform apply -replace=aws_apprunner_service.admin_dashboard_backend
```

## Monitoring and Logs

### View Logs

```bash
# Using AWS CLI
aws apprunner list-operations --service-arn $(terraform output -raw apprunner_service_arn)
```

### CloudWatch Logs

Logs are automatically sent to CloudWatch Logs:
- Log Group: `/aws/apprunner/<service-name>/application`

## Cost Estimation

**Monthly costs** (approximate):

- **App Runner**: ~$25-100/month (1-2 instances, 1 vCPU, 2GB RAM)
- **ECR Storage**: ~$0.10/GB/month
- **Data Transfer**: Variable based on traffic

## Troubleshooting

### GitHub Connection Issues

**Problem**: Connection status shows "PENDING_HANDSHAKE"
**Solution**: 
1. Go to AWS Console → App Runner → GitHub connections
2. Complete the OAuth authorization flow
3. Run `terraform apply` again

**Problem**: "Connection not authorized" error
**Solution**: The GitHub connection must be manually authorized in AWS Console after creation

### Service fails to start

1. Check CloudWatch logs for errors
2. Verify database connectivity
3. Ensure environment variables are correct
4. Verify `requirements.txt` includes all dependencies
5. Check build/start commands are correct

### Database connection issues

1. If RDS is in private subnet, enable VPC connector
2. Verify security group rules allow App Runner access
3. Check database credentials

### Build Failures

1. Check CloudWatch logs: `/aws/apprunner/<service-name>/service`
2. Verify `requirements.txt` is in repository root
3. Ensure Python version compatibility
4. Check build command syntax

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

**Warning**: This will delete the App Runner service and ECR repository (including all images).

## Security Best Practices

1. ✅ Use AWS Secrets Manager for sensitive data
2. ✅ Enable VPC connector for private database access
3. ✅ Use IAM roles instead of access keys
4. ✅ Enable ECR image scanning
5. ✅ Rotate database credentials regularly
6. ✅ Use HTTPS only (App Runner provides this by default)
7. ✅ Implement proper CORS policies

## Support

For issues or questions:
- Check AWS App Runner documentation
- Review CloudWatch logs
- Verify Terraform state: `terraform show`
