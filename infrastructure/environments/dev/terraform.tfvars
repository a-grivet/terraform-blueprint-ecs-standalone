# ============================================================================
# TERRAFORM VARIABLES FILE (terraform.tfvars)
# ============================================================================
# This file contains the actual values for variables used in your Terraform configuration.
# Think of this as the "settings file" where you customize your infrastructure.
# Each variable defined in variables.tf gets its value assigned here.
#
# IMPORTANT: This file contains environment-specific values and should be customized
# for each environment (dev, staging, prod). Never commit sensitive data like passwords.
# ============================================================================

# ============================================================================
# PROJECT IDENTIFICATION
# ============================================================================
# These variables identify your project and environment

project_name = "ecs-standalone"  # Short name for your project (used in resource names)
environment  = "dev"         # Environment name: dev, staging, or prod
region   = "eu-west-1"       # AWS region where resources will be created

# ============================================================================
# NETWORKING (Existing Infrastructure)
# ============================================================================
# These are existing network resources.
# Replace these IDs with your actual VPC and subnet IDs from your AWS account.

vpc_id = "vpc-xxxxxxxxxxxxxxxxx"  # The VPC (Virtual Private Cloud) where all resources will be deployed

# Public subnets: Used for internet-facing resources like the Load Balancer
# Must be in different Availability Zones (AZs) for high availability
public_subnet_ids = [
  "subnet-xxxxxxxxxxxxxxxxx",  # Public subnet in eu-west-1a
  "subnet-xxxxxxxxxxxxxxxxx"   # Public subnet in eu-west-1b
]

# Private subnets: Used for backend resources like EC2 instances and databases
# These subnets don't have direct internet access (more secure)
private_subnet_ids = [
  "subnet-xxxxxxxxxxxxxxxxx",  # Private subnet in eu-west-1a
  "subnet-xxxxxxxxxxxxxxxxx"   # Private subnet in eu-west-1b
]

# ============================================================================
# DNS & SSL/TLS CERTIFICATE CONFIGURATION
# ============================================================================
# These settings configure your custom domain name and HTTPS certificate

# IMPORTANT: Replace these with your actual Route53 hosted zone details
domain_name = "ecs-standalone.your-account-alias-dev.np.org-aws.net"  # Your application's domain name (where users access your app)
zone_name   = "your-account-alias-dev.np.org-aws.net"              # Your Route53 hosted zone (parent domain)
zone_id     = "ZXXXXXXXXXXXXXXXXXX"                                # Route53 hosted zone ID

# Enable CloudWatch monitoring for certificate expiration (optional)
enable_certificate_monitoring = true  # Set to true to receive alerts when certificate is about to expire

# ============================================================================
# APPLICATION PORT
# ============================================================================
# Port your application listens on - used for security groups and ALB

app_port = 80
# Examples:
# - 80 = nginx, Apache
# - 3000 = Node.js


# ============================================================================
# DATABASE CONFIGURATION (Aurora PostgreSQL)
# ============================================================================
# Aurora is AWS's managed database service with automatic failover and scaling

# --- Database Engine ---
db_engine         = "aurora-postgresql"  # Database type (PostgreSQL-compatible)
db_engine_version = "17.4"               # PostgreSQL version

# --- Database Credentials ---
# Note: The password is NOT stored here (security best practice)
# It will be automatically generated and stored in AWS Secrets Manager
db_name     = "ecsstandalonedev"  # Database name (alphanumeric only, no hyphens)
db_username = "dbadmin"       # Master username for database access
db_port     = 5432            # PostgreSQL default port

# --- Database Cluster Configuration ---
db_instance_class   = "db.t3.medium"  # Instance size to adapt according your need
db_writer_instances = 1               # Number of writer instances (handles writes)
db_reader_instances = 1               # Number of reader instances (handles reads, improves performance)

# --- Backup and Maintenance ---
db_backup_retention_period = 7                      # Keep backups for 7 days
db_backup_window           = "03:00-04:00"          # Daily backup window (UTC time, low-traffic period)
db_maintenance_window      = "sun:04:00-sun:05:00"  # Weekly maintenance window (UTC time, Sunday early morning)


# ============================================================================
# IAM PERMISSIONS
# ============================================================================
# Permission boundary: A security control that limits the maximum permissions
# that IAM roles can have. This prevents privilege escalation.

permissions_boundary_arn = "arn:aws:iam::670943688569:policy/OrgPermissionBoundary"


# ============================================================================
# CONTAINER CONFIGURATION
# ============================================================================
# IMPORTANT: Use public image for FIRST deployment, then switch to your ECR image

# Phase 1 (initial deployment): Use nginx to validate infrastructure
# Comment this line to Switch on your ECR image (During phase2)
# container_image = "nginx:latest"
# container_port  = 80

# Phase 2 : Switch to your application
# Customize and uncomment 2 lines beslow to Switch on your ECR image (Phase2)
# container_image = "123456789.dkr.ecr.eu-west-1.amazonaws.com/ecs-standalone-dev:v1.0" 
container_image  = "670943688569.dkr.ecr.eu-west-1.amazonaws.com/ecs-standalone-dev:latest"
ecs_desired_count = 2
container_port   = 80

# ============================================================================
# ECS TASK RESOURCES
# ============================================================================

task_cpu    = 256   # 0.25 vCPU
task_memory = 512   # 512 MB

# Valid CPU/Memory combinations:
# CPU 256:  512, 1024, 2048
# CPU 512:  1024, 2048, 3072, 4096
# CPU 1024: 2048, 3072, 4096, 5120, 6144, 7168, 8192
# CPU 2048: 4096 to 16384 (in 1GB increments)
# CPU 4096: 8192 to 30720 (in 1GB increments)

# Sizing recommendations:
# - Dev/Test:    256 CPU + 512 MB
# - Small API:   512 CPU + 1024 MB
# - Medium App:  1024 CPU + 2048 MB
# - Large App:   2048 CPU + 4096 MB

# ============================================================================
# REDIS CONFIGURATION (REQUIRED)
# ============================================================================

redis_node_type      = "cache.t3.micro"
redis_num_cache_nodes = 1

# Node types:
# Burstable (T3) - Cheaper, good for dev/test:
#   - cache.t3.micro:  0.5 GB RAM
#   - cache.t3.small:  1.37 GB RAM
#   - cache.t3.medium: 3.09 GB RAM
#
# Memory-optimized (R6G) - Better for production caching:
#   - cache.r6g.large:   13.07 GB RAM
#   - cache.r6g.xlarge:  26.32 GB RAM
#   - cache.r6g.2xlarge: 52.82 GB RAM

# High Availability (Prod):
# redis_node_type              = "cache.r6g.large"
# redis_num_cache_nodes         = 2
# redis_automatic_failover_enabled = true
# redis_multi_az_enabled        = true



# ============================================================================
# MONITORING & ALERTING
# ============================================================================
# CloudWatch will send alerts to this email when something goes wrong

alert_email = "your-alert-email@example.com"  # Email address for alarm notifications

# Database connection alarm threshold
# Alert will trigger if database connections exceed this value (potential issue)
database_connection_threshold = 80  # Maximum number of concurrent database connections before alerting


# ============================================================================
# HEALTH CHECK CONFIGURATION
# ============================================================================
# Health checks determine if an instance is functioning properly

health_check_path = "/"
target_type = "ip"


# ============================================================================
# DYNAMODB TABLES (OPTIONAL - Disabled by default)
# ============================================================================
# Enable DynamoDB for: sessions, caching, feature flags, rate limiting
# Keep disabled if you only need Aurora (relational data)
# 
# When to enable:
# - Session storage (shopping carts, user sessions) with auto-expiry
# - Event tracking / analytics with time-series data
# - Feature flags / app configuration
# - Rate limiting / API throttling
# 
# Cost: ~$1/month per 1M requests (pay-per-request)
# See README.md "Enable DynamoDB" section for code examples

# Default: DISABLED (no DynamoDB tables created)
dynamodb_tables = {} # comment this line and uncomment DynamoDB bloc below to enable 

# Example: Session management (uncomment to enable)
# dynamodb_tables = {
#   sessions = {
#     billing_mode           = "PAY_PER_REQUEST"
#     hash_key               = "session_id"
#     hash_key_type          = "S"
#     range_key              = null
#     range_key_type         = null
#     ttl_enabled            = true
#     ttl_attribute_name     = "expires_at"
#     point_in_time_recovery = true
#     deletion_protection    = true
#     global_secondary_indexes = []
#     local_secondary_indexes  = []
#     stream_enabled         = false
#     stream_view_type       = null
#   }
# }


# ============================================================================
# RESOURCE TAGS
# ============================================================================
# Tags are key-value pairs attached to AWS resources for organization,
# cost tracking, and automation. These tags will be applied to all resources.

tags = {
  Environment = "dev"                      # Environment identifier
  Pattern     = "ecs-standalone"    # Architecture pattern name
  ManagedBy   = "terraform"                # Indicates infrastructure is managed by Terraform
  CostCenter = "your-cost-center"                 # Cost allocation tag
}