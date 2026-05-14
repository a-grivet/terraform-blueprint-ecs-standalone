#!/bin/bash
# ============================================================================
# BUILD AND PUSH SCRIPT - ECS Demo Application to ECR
# ============================================================================
# This script automates the process of:
# 1. Building the Docker image
# 2. Authenticating to AWS ECR
# 3. Tagging the image with version
# 4. Pushing to ECR repository
#
# Usage:
#   ./build-and-push.sh [version]
#   
# Example:
#   ./build-and-push.sh v1.0
#   ./build-and-push.sh v1.1
#
# If no version is provided, defaults to v1.0
# ============================================================================

set -e  # Exit on error

# ============================================================================
# CONFIGURATION
# ============================================================================

# Default version if not provided
VERSION="${1:-v1.0}"

# AWS Configuration
AWS_REGION="eu-west-1"
ENVIRONMENT="dev"  # Change to "prod" for production

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# FUNCTIONS
# ============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}=========================================="
    echo -e "$1"
    echo -e "==========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================

print_header "🐳 Building and Pushing ECS Demo App to ECR"

# Step 1: Get AWS Account ID
print_info "Getting AWS Account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    print_error "Failed to get AWS Account ID. Are you authenticated?"
    exit 1
fi
print_success "AWS Account ID: $AWS_ACCOUNT_ID"

# Step 2: Construct ECR repository URL
REPO_NAME="ecs-standalone-${ENVIRONMENT}"
ECR_URL="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${REPO_NAME}"
print_success "ECR Repository: $ECR_URL"

# Step 3: Check if ECR repository exists
print_info "Checking if ECR repository exists..."
if aws ecr describe-repositories --repository-names "$REPO_NAME" --region "$AWS_REGION" &>/dev/null; then
    print_success "ECR repository exists"
else
    print_error "ECR repository '$REPO_NAME' not found in region $AWS_REGION"
    print_info "Run 'terraform apply' first to create the ECR repository"
    exit 1
fi

# Step 4: Build Docker image
print_header "🔨 Building Docker Image"
print_info "Building image with tag: ecs-demo:${VERSION}"

if docker build -t ecs-demo:${VERSION} .; then
    print_success "Docker image built successfully"
else
    print_error "Docker build failed"
    exit 1
fi

# Step 5: Authenticate to ECR
print_header "🔐 Authenticating to ECR"
print_info "Getting ECR login credentials..."

if aws ecr get-login-password --region "$AWS_REGION" | \
   docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"; then
    print_success "Successfully authenticated to ECR"
else
    print_error "ECR authentication failed"
    exit 1
fi

# Step 6: Tag image for ECR
print_header "🏷️  Tagging Image for ECR"
print_info "Tagging image: ${ECR_URL}:${VERSION}"

if docker tag ecs-demo:${VERSION} ${ECR_URL}:${VERSION}; then
    print_success "Image tagged for ECR"
else
    print_error "Failed to tag image"
    exit 1
fi

# Also tag as latest
print_info "Tagging image as latest"
if docker tag ecs-demo:${VERSION} ${ECR_URL}:latest; then
    print_success "Image tagged as latest"
else
    print_error "Failed to tag image as latest"
    exit 1
fi

# Step 7: Push to ECR
print_header "🚀 Pushing Image to ECR"
print_info "Pushing ${ECR_URL}:${VERSION}"

if docker push ${ECR_URL}:${VERSION}; then
    print_success "Image ${VERSION} pushed successfully"
else
    print_error "Failed to push image ${VERSION}"
    exit 1
fi

print_info "Pushing ${ECR_URL}:latest"
if docker push ${ECR_URL}:latest; then
    print_success "Image latest pushed successfully"
else
    print_error "Failed to push image latest"
    exit 1
fi

# Step 8: Verify image in ECR
print_header "✅ Verification"
print_info "Listing images in ECR repository..."

aws ecr list-images \
    --repository-name "$REPO_NAME" \
    --region "$AWS_REGION" \
    --output table

# Step 9: Display summary
print_header "📋 Deployment Summary"
echo -e "${GREEN}✅ Image successfully built and pushed!${NC}"
echo ""
echo "Repository:  $REPO_NAME"
echo "Version:     $VERSION"
echo "Image URI:   ${ECR_URL}:${VERSION}"
echo "Latest URI:  ${ECR_URL}:latest"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Use this image URI in your ECS task definition"
echo "2. Update the ECS service to use the new image"
echo "3. Monitor the deployment in the AWS Console"
echo ""
echo "Image URI for ECS Task Definition:"
echo -e "${BLUE}${ECR_URL}:${VERSION}${NC}"
echo ""
print_success "Done! 🎉"
