# ============================================================================
# DOCKERFILE - ECS Fargate Demo Application
# ============================================================================
# This Dockerfile creates a simple web application that displays:
# - "Hello from <ECS Task ID>"
# - Task metadata (IP, AZ, etc.)
# - Similar to the ASG EC2 demo, but for ECS Fargate
#
# The application uses nginx to serve a dynamically generated HTML page
# that shows which ECS task is handling the request (useful for testing
# load balancing across multiple Fargate tasks)
# ============================================================================

# Use official nginx alpine image (small size ~23MB)
FROM nginx:alpine

# Install curl and jq for fetching ECS metadata
RUN apk add --no-cache curl jq bash

# Create directory for our custom scripts
RUN mkdir -p /app

# Copy the entrypoint script that will generate the HTML page
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Copy custom nginx configuration (optional, for health checks)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 80 (nginx default)
EXPOSE 80

# Use our custom entrypoint that generates the page before starting nginx
ENTRYPOINT ["/app/entrypoint.sh"]

# Health check - nginx must respond on port 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

# ============================================================================
# BUILD AND RUN INSTRUCTIONS:
# ============================================================================
# 
# 1. Build the image:
#    docker build -t ecs-demo:latest .
#
# 2. Test locally:
#    docker run -p 8080:80 ecs-demo:latest
#    curl http://localhost:8080
#
# 3. Tag for ECR:
#    docker tag ecs-demo:latest ACCOUNT.dkr.ecr.REGION.amazonaws.com/ecs-standalone-dev:v1.0
#
# 4. Push to ECR:
#    aws ecr get-login-password --region eu-west-1 | docker login --username AWS --password-stdin ACCOUNT.dkr.ecr.REGION.amazonaws.com
#    docker push ACCOUNT.dkr.ecr.REGION.amazonaws.com/ecs-standalone-dev:v1.0
#
# ============================================================================
