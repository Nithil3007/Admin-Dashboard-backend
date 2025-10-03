# Quick Deployment Guide - GitHub to AWS App Runner

## 🚀 One-Time Setup

### 1. Push your code to GitHub
```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/YOUR-USERNAME/admin-dashboard-backend.git
git push -u origin main
```

### 2. Configure Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and set:
- `github_repository_url = "https://github.com/YOUR-USERNAME/admin-dashboard-backend"`
- `github_branch = "main"`
- Database credentials (db_host, db_name, db_user, db_password)

### 3. Deploy
```bash
cd ..
chmod +x deploy.sh
./deploy.sh
```

### 4. Authorize GitHub Connection
After first deployment:
1. Go to [AWS Console → App Runner → GitHub connections](https://console.aws.amazon.com/apprunner/home#/connections)
2. Find `admin-dashboard-backend-github-connection`
3. Click **"Complete handshake"**
4. Authorize with GitHub
5. Run `./deploy.sh` again

## 🔄 Future Updates

Just push to GitHub - it auto-deploys!
```bash
git add .
git commit -m "Your changes"
git push origin main
```

## 📋 Key Configuration

### Terraform Variables (`terraform.tfvars`)

**Required:**
- `github_repository_url` - Your GitHub repo URL
- `db_host` - Database hostname
- `db_name` - Database name
- `db_user` - Database username
- `db_password` - Database password

**Optional:**
- `github_branch` - Branch to deploy (default: "main")
- `cpu` - CPU units (default: "1024")
- `memory` - Memory in MB (default: "2048")
- `min_instances` - Min instances (default: 1)
- `max_instances` - Max instances (default: 5)
- `enable_vpc_connector` - For private RDS (default: false)

### Environment Variables (Auto-configured)

App Runner automatically sets:
- `DB_HOST`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`
- `DB_PORT`
- `ENVIRONMENT`

Access in Python:
```python
import os
db_host = os.getenv("DB_HOST")
```

## 🔧 Common Commands

```bash
# View service URL
cd terraform && terraform output apprunner_service_url

# View all outputs
cd terraform && terraform output

# Force new deployment
cd terraform && terraform apply -replace=aws_apprunner_service.admin_dashboard_backend

# Destroy everything
cd terraform && terraform destroy
```

## 📊 Monitoring

**CloudWatch Logs:**
- Service logs: `/aws/apprunner/<service-name>/service`
- Application logs: `/aws/apprunner/<service-name>/application`

**View in Console:**
https://console.aws.amazon.com/apprunner/home

## 💰 Estimated Costs

- **App Runner**: ~$25-100/month (1-2 instances, 1 vCPU, 2GB RAM)
- **Data Transfer**: Variable based on traffic
- **No ECR costs** (using GitHub source)

## 🐛 Troubleshooting

### Connection shows "PENDING_HANDSHAKE"
→ Authorize the GitHub connection in AWS Console

### Build fails
→ Check CloudWatch logs for errors
→ Verify `requirements.txt` is complete
→ Ensure Python 3.9+ compatibility

### Can't connect to database
→ If RDS is private, set `enable_vpc_connector = true`
→ Verify security groups allow App Runner access
→ Check database credentials

### Service won't start
→ Check environment variables are set correctly
→ Verify port 8080 is exposed in your app
→ Review application logs in CloudWatch

## 📚 Full Documentation

See `terraform/README.md` for comprehensive documentation.
