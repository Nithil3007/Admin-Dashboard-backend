#!/bin/bash

# Deployment script for Admin Dashboard Backend to AWS App Runner (GitHub Source)
# This script pushes code to GitHub and deploys via Terraform

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION=${AWS_REGION:-"us-east-2"}
APP_NAME="admin-dashboard-backend"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Admin Dashboard Backend Deployment${NC}"
echo -e "${GREEN}========================================${NC}"

# Check prerequisites
echo -e "\n${YELLOW}Checking prerequisites...${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: Git is not installed${NC}"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

# Check if git repository is initialized
if [ ! -d ".git" ]; then
    echo -e "${RED}Error: Not a git repository. Please initialize git first:${NC}"
    echo -e "${BLUE}  git init${NC}"
    echo -e "${BLUE}  git add .${NC}"
    echo -e "${BLUE}  git commit -m 'Initial commit'${NC}"
    echo -e "${BLUE}  git remote add origin <your-github-repo-url>${NC}"
    echo -e "${BLUE}  git push -u origin main${NC}"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo -e "\n${YELLOW}Uncommitted changes detected. Committing...${NC}"
    git add .
    read -p "Enter commit message (or press Enter for default): " COMMIT_MSG
    COMMIT_MSG=${COMMIT_MSG:-"Update application"}
    git commit -m "$COMMIT_MSG"
fi

# Push to GitHub
echo -e "\n${YELLOW}Pushing to GitHub...${NC}"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
git push origin $CURRENT_BRANCH

echo -e "${GREEN}✓ Code pushed to GitHub (branch: ${CURRENT_BRANCH})${NC}"

# Initialize Terraform if needed
if [ ! -d "terraform/.terraform" ]; then
    echo -e "\n${YELLOW}Initializing Terraform...${NC}"
    cd terraform
    terraform init
    cd ..
fi

# Check if terraform.tfvars exists
if [ ! -f "terraform/terraform.tfvars" ]; then
    echo -e "\n${YELLOW}terraform.tfvars not found. Creating from example...${NC}"
    cp terraform/terraform.tfvars.example terraform/terraform.tfvars
    echo -e "${RED}Please edit terraform/terraform.tfvars with your configuration and run this script again.${NC}"
    exit 1
fi

# Deploy with Terraform
echo -e "\n${YELLOW}Deploying to App Runner with Terraform...${NC}"
cd terraform
terraform apply

# Check GitHub connection status
CONNECTION_STATUS=$(terraform output -raw github_connection_status 2>/dev/null || echo "unknown")
cd ..

if [ "$CONNECTION_STATUS" = "PENDING_HANDSHAKE" ]; then
    echo -e "\n${YELLOW}========================================${NC}"
    echo -e "${YELLOW}ACTION REQUIRED: GitHub Connection${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${RED}The GitHub connection needs to be authorized!${NC}"
    echo -e "\n${BLUE}Steps:${NC}"
    echo -e "1. Go to AWS Console → App Runner → GitHub connections"
    echo -e "2. Find connection: ${APP_NAME}-github-connection"
    echo -e "3. Click 'Complete handshake' or 'Authorize'"
    echo -e "4. Authenticate with GitHub"
    echo -e "5. Run this script again: ${GREEN}./deploy.sh${NC}"
    exit 0
fi

# Get service URL
cd terraform
SERVICE_URL=$(terraform output -raw apprunner_service_url 2>/dev/null || echo "")
cd ..

if [ -n "$SERVICE_URL" ]; then
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}Deployment Complete!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Service URL: https://${SERVICE_URL}${NC}"
    echo -e "${GREEN}Health Check: https://${SERVICE_URL}/${NC}"
    echo -e "\n${BLUE}Auto-deploy is enabled. Future pushes to '${CURRENT_BRANCH}' will automatically deploy!${NC}"
    echo -e "\n${YELLOW}Note: It may take a few minutes for the service to become fully available.${NC}"
else
    echo -e "\n${YELLOW}Deployment initiated. Check AWS Console for status.${NC}"
fi
