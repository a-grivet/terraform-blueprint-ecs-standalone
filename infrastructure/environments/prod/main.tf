# ============================================================================
# MAIN INFRASTRUCTURE CONFIGURATION - PROD ENVIRONMENT
# ============================================================================
# This file orchestrates all infrastructure modules to deploy a complete
# 3-tier web application stack in AWS:
# - Presentation tier: Application Load Balancer (public subnets)
# - Application tier: ECS Fargate containers (private subnets)
# - Data tier: Aurora RDS cluster + ElastiCache Redis + DynamoDB (private subnets)
#
#
# Module dependencies:
# 1. Security Groups (network firewall rules)
# 2. KMS keys (encryption)
# 3. ACM certificate (HTTPS)
# 4. IAM role (EC2 permissions)
# 5. Secrets Manager (database password)
# 6. ALB (load balancer)
# 7. ECR (container registry)
# 8. ECS Fargate (containers)
# 9. Aurora (database)
# 10. ElastiCache Redis (cache)
# 11. DynamoDB (NoSQL)
# 12. Monitoring (CloudWatch)
# 13. SSM Parameters (Aurora cluster writer endpoint)


# ============================================================================
# DATA SOURCES - AWS Account and Region Information
# ============================================================================

data "aws_caller_identity" "current" {}
# Get current AWS account ID
# Used for: Resource naming, IAM ARNs, account-specific configurations
# Example: account_id = "123456789012"

data "aws_region" "current" {}
# Get current AWS region
# Used for: Regional resource identifiers, availability zones
# Example: name = "eu-west-1"

# ============================================================================
# MODULE: SECURITY GROUPS - Network Firewall Rules
# ============================================================================
# Creates security groups for 3-tier architecture

module "security_groups" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/security-groups?ref=v1.0.0"

  project_name = var.project_name # Project identifier for naming
  environment  = var.environment  # Environment (dev, staging, prod)
  vpc_id       = var.vpc_id       # Existing VPC ID
  app_port     = var.app_port
  enable_redis = true
  redis_port   = 6379
  tags         = var.tags # Common resource tags
  # Security groups created:
  # 1. ALB security group: Allows HTTP/HTTPS from internet
  # 2. App security group: Allows traffic from ALB only
  # 3. DB security group: Allows traffic from app tier only
  # 4. Redis security group: Allows traffic from app tier only
  # 
  # Traffic flow:
  # Internet (0.0.0.0/0) → ALB:443 → App:var.app_port → DB:5432 / Redis:6379
  # 
}

# ============================================================================
# MODULE: ACM CERTIFICATE - SSL/TLS Certificate
# ============================================================================
# Creates and validates SSL/TLS certificate for HTTPS

module "acm_certificate" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/acm-alb?ref=v1.0.0"

  # Domain configuration
  domain_name = var.domain_name # Example: app.prod.mydomain.com
  zone_id     = var.zone_id     # Route53 hosted zone ID
  zone_name   = var.zone_name   # Route53 hosted zone name
  environment = var.environment
  CostCenter  = var.project_name


  # Certificate expiry monitoring
  enable_expiry_alarm         = var.enable_certificate_monitoring
  expiry_alarm_threshold_days = 30 # Alert 30 days before expiry
  # Note: ACM certificates auto-renew if DNS validation stays valid


  tags = merge(
    var.tags,
    { Component = "Certificate" }
  )

  # Certificate features:
  # - Automatic DNS validation (no manual email validation)
  # - Automatic renewal (before expiration)
  # 
  # HTTPS workflow:
  # 1. Request certificate for domain
  # 2. Create DNS validation record in Route53
  # 3. Wait for validation (usually < 5 minutes)
  # 4. Attach certificate to ALB HTTPS listener
}

# ============================================================================
# MODULE: APPLICATION LOAD BALANCER - Layer 7 Load Balancer
# ============================================================================
# Creates internet-facing ALB for HTTPS traffic distribution

module "alb" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/alb?ref=v1.0.0"

  # Basic configuration
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = var.vpc_id

  # Network configuration
  subnet_ids         = var.public_subnet_ids # Deploy in public subnets (internet-facing)
  security_group_ids = [module.security_groups.alb_security_group_id]
  internal           = false # Internet-facing (not internal)

  # HTTPS configuration
  certificate_arn = module.acm_certificate.certificate_arn
  ssl_policy      = var.alb_ssl_policy

  # Target group configuration
  target_group_port     = var.app_port
  target_group_protocol = "HTTP" # HTTP between ALB and instances (internal network)
  deregistration_delay  = var.alb_deregistration_delay
  target_type           = var.target_type

  # Health check configuration 
  health_check_path                = var.health_check_path
  health_check_protocol            = "HTTP"
  health_check_interval            = var.health_check_interval
  health_check_timeout             = var.health_check_timeout
  health_check_healthy_threshold   = var.health_check_healthy_threshold
  health_check_unhealthy_threshold = var.health_check_unhealthy_threshold
  health_check_matcher             = var.health_check_matcher

  # CloudWatch alarms
  enable_cloudwatch_alarms         = true
  unhealthy_target_alarm_threshold = var.monitoring_unhealthy_target_threshold
  response_time_alarm_threshold    = var.monitoring_alb_response_time_threshold
  http_5xx_alarm_threshold         = var.monitoring_alb_5xx_threshold

  tags = merge(
    var.tags,
    { Component = "LoadBalancer" }
  )
}

# ============================================================================
# ROUTE53 DNS RECORD - Domain Name Resolution
# ============================================================================
# Creates DNS A record pointing to ALB

resource "aws_route53_record" "app" {
  zone_id = module.acm_certificate.route53_zone_id
  name    = var.domain_name # Example: app.prod.your-org.com
  type    = "A"             # A record (maps domain to IPv4 address)

  alias {
    name                   = module.alb.alb_dns_name # ALB DNS name
    zone_id                = module.alb.alb_zone_id  # ALB hosted zone ID
    evaluate_target_health = true                    # Check ALB health for DNS routing
  }
  # DNS configuration:
  # - Type: A (Address record)
  # - Alias: Points to ALB
  # 
  # DNS resolution flow:
  # 1. User types: https://app.prod.mydomain.com
  # 2. Browser queries DNS for app.prod.mydomain.com
  # 3. Route53 returns ALB DNS name
  # 4. Browser resolves ALB DNS to IP addresses
  # 5. Browser connects to ALB IP on port 443
}

# ============================================================================
# MODULE: KMS KEYS - Encryption Keys
# ============================================================================

# KMS key for RDS database encryption
module "kms_rds" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/kms?ref=v1.0.0"

  project_name = var.project_name
  environment  = var.environment
  key_name     = "rds" # Key identifier
  description  = "Aurora database encryption"

  tags = var.tags
  # RDS encryption:
  # - Database storage: All data at rest
  # - Automated backups: Encrypted with same key
  # - Snapshots: Encrypted with same key
  # - Read replicas: Must use same key
}

# KMS key for Secrets Manager encryption
module "kms_secrets" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/kms?ref=v1.0.0"

  project_name = var.project_name
  environment  = var.environment
  key_name     = "secrets" # Key identifier
  description  = "Secrets Manager encryption"

  tags = var.tags
}

# KMS key for DynamoDB tables encryption
module "kms_dynamodb" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/kms?ref=v1.0.0"

  project_name = var.project_name
  environment  = var.environment
  key_name     = "dynamodb"
  description  = "DynamoDB tables encryption"

  tags = var.tags
}

# KMS key for Elasticache Redis encryption
module "kms_redis" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/kms?ref=v1.0.0"

  project_name = var.project_name
  environment  = var.environment
  key_name     = "redis"
  description  = "ElastiCache Redis encryption"

  tags = var.tags
}


# ============================================================================
# MODULE: ECR - Container Image Registry
# ============================================================================
# Creates private Docker repository for application images

module "ecr" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/ecr?ref=v1.0.0"

  project_name = var.project_name
  environment  = var.environment

  # Development settings 
  image_tag_mutability = var.ecr_image_tag_mutability
  scan_on_push         = var.ecr_scan_on_push

  # Lifecycle policy 
  lifecycle_policy_max_image_count = var.ecr_max_image_count
  lifecycle_policy_untagged_days   = var.ecr_untagged_days

  # Encryption - NOW VARIABLE
  encryption_type = var.ecr_encryption_type

  tags = merge(
    var.tags,
    { Component = "ContainerRegistry" }
  )
}

# ============================================================================
# MODULE: ECS FARGATE - Complete Container Environment
# ============================================================================
# This module creates everything needed for ECS Fargate:
# - IAM Roles (Task Execution + Task)
# - ECS Cluster
# - CloudWatch Log Group
# - ECS Task Definition
# - ECS Service with ALB integration

module "ecs" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/ecs?ref=v1.0.0"

  # ===== GENERAL =====
  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags

  # ===== CONTAINER CONFIGURATION  =====
  container_name  = var.container_name
  container_image = var.container_image
  container_port  = var.container_port

  # Environment variables
  environment_variables = {
    APP_ENV  = var.environment
    APP_NAME = var.project_name
    PORT     = tostring(var.container_port)
  }

  # Secrets from Secrets Manager / SSM (if needed)
  secrets = {
    # Example: DB_PASSWORD = module.secrets_manager_db_secret.secret_arn
  }

  # ===== COMPUTE RESOURCES  =====
  task_cpu    = var.task_cpu
  task_memory = var.task_memory

  # ===== NETWORK CONFIGURATION =====
  subnet_ids         = var.private_subnet_ids
  security_group_ids = [module.security_groups.app_sg_id]
  assign_public_ip   = false # Use NAT Gateway for internet access

  # ===== LOAD BALANCER =====
  alb_target_group_arn = module.alb.target_group_arn

  # ===== SERVICE CONFIGURATION  =====
  desired_count                      = var.ecs_desired_count
  deployment_minimum_healthy_percent = var.ecs_deployment_min_healthy_percent
  deployment_maximum_percent         = var.ecs_deployment_max_percent

  # ===== DEPLOYMENT FEATURES  =====
  enable_circuit_breaker          = var.ecs_enable_circuit_breaker
  enable_circuit_breaker_rollback = var.ecs_enable_circuit_breaker # Same as circuit_breaker
  enable_execute_command          = var.ecs_enable_execute_command

  # ===== CLUSTER CONFIGURATION  =====
  enable_container_insights = var.ecs_enable_container_insights
  capacity_providers        = ["FARGATE"]
  log_retention_days        = var.ecs_log_retention_days

  # ===== IAM CONFIGURATION =====
  enable_secrets_access = true
  secrets_manager_arns  = [module.db_secret.secret_arn]
  kms_key_arns          = [module.kms_secrets.key_arn]

  # Custom task policies (if needed)
  task_custom_policies     = {}
  task_managed_policy_arns = []

  depends_on = [
    module.alb,
    module.ecr
  ]
}

# ============================================================================
# MODULE: SECRETS MANAGER - Database Password Storage
# ============================================================================
# Stores Aurora master password securely with KMS encryption

module "db_secret" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/secrets-manager?ref=v1.0.0"

  project_name = var.project_name
  environment  = var.environment
  secret_name  = "db-master-password"
  description  = "Master password for Aurora database"

  # Encryption
  kms_key_id = module.kms_secrets.key_id # Customer-managed KMS key

  # Password generation 
  create_random_password  = true # Auto-generate secure password
  password_length         = var.secrets_password_length
  recovery_window_in_days = var.secrets_recovery_window_days

  tags = var.tags
}

# Retrieve password for Aurora module (Terraform only, not applications)
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = module.db_secret.secret_id

  depends_on = [module.db_secret]
  # This data source retrieves the password value for passing to Aurora module
  # Applications should retrieve password directly from Secrets Manager
  # (not via Terraform outputs)
}

# ============================================================================
# REDIS AUTH TOKEN - Generate secure password
# ============================================================================

resource "random_password" "redis_auth_token" {
  length  = 32
  special = true
  # Redis auth token only allows specific special chars
  override_special = "!&#$^<>-"
}

resource "aws_secretsmanager_secret" "redis_auth_token" {
  name_prefix = "${var.project_name}-${var.environment}-redis-token-"
  description = "Redis authentication token for ${var.project_name} ${var.environment}"
  kms_key_id  = module.kms_secrets.key_id

  tags = merge(
    var.tags,
    {
      Name        = "${var.project_name}-${var.environment}-redis-token"
      Environment = var.environment
      Component   = "Cache"
    }
  )
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  secret_id = aws_secretsmanager_secret.redis_auth_token.id
  secret_string = jsonencode({
    token    = random_password.redis_auth_token.result
    endpoint = module.redis.primary_endpoint
    port     = module.redis.port
    url      = "redis://${module.redis.primary_endpoint}:${module.redis.port}"
  })

  depends_on = [module.redis]
}

# ============================================================================
# MODULE: RDS AURORA - Database Cluster
# ============================================================================
# Creates Aurora PostgreSQL cluster with read replicas

module "aurora" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/aurora?ref=v1.0.0"

  # General configuration
  project_name = var.project_name
  environment  = var.environment

  # Network configuration
  db_subnet_ids         = var.private_subnet_ids # Private subnets (2 AZs minimum)
  db_security_group_ids = [module.security_groups.db_security_group_id]

  # Engine configuration
  engine         = var.db_engine         # Example: aurora-postgresql
  engine_version = var.db_engine_version # Example: 15.4
  engine_mode    = "provisioned"         # Provisioned (not serverless)

  # Database configuration
  database_name   = var.db_name                                                      # Database name
  master_username = var.db_username                                                  # Master username
  master_password = data.aws_secretsmanager_secret_version.db_password.secret_string # retrieve password from secret manager
  port            = var.db_port                                                      # Port: 5432 (PostgreSQL) or 3306 (MySQL)

  # Instance configuration
  instance_class   = var.db_instance_class   # Example: db.t4g.medium
  writer_instances = var.db_writer_instances # Number of writer instances
  reader_instances = var.db_reader_instances # Number of reader instances 

  # Encryption
  storage_encrypted = true
  kms_key_id        = module.kms_rds.key_arn # Customer-managed KMS key

  # Backup configuration
  backup_retention_period      = var.db_backup_retention_period          # Backup rentention in days. exemple: 7 (dev), 30 (prod)
  preferred_backup_window      = var.db_backup_window                    # Example: "03:00-04:00"
  preferred_maintenance_window = var.db_maintenance_window               # Example: "sun:04:00-sun:05:00"
  skip_final_snapshot          = var.environment == "dev" ? true : false # Skip for dev only

  # Monitoring - NOW VARIABLES
  enabled_cloudwatch_logs_exports = var.db_engine == "aurora-postgresql" ? ["postgresql"] : ["error", "general", "slowquery"]
  monitoring_interval             = var.db_monitoring_interval
  performance_insights_enabled    = var.db_performance_insights_enabled

  # Deletion protection
  deletion_protection = var.environment == "prod" ? true : false # Protect prod only

  tags = merge(
    var.tags,
    { Component = "Database" }
  )

  depends_on = [
    module.security_groups,
    module.kms_rds,
    module.db_secret
  ]
  # Aurora features:
  # - High availability: Multi-AZ deployment
  # - Read replicas: Up to 15 read replicas
  # - Automatic failover: <30 seconds
  # - Continuous backup: Point-in-time recovery
  # - Automated patching: Maintenance window
  # - Performance Insights: Query analysis
  # 
  # Writer vs Reader endpoints:
  # - Writer: Primary instance (read/write operations)
  # - Reader: Load-balanced read replicas (read-only operations)
}

# ============================================================================
# MODULE: DYNAMODB - NoSQL Database (OPTIONAL)
# ============================================================================
# Creates DynamoDB tables for hot data, sessions, and high-throughput use cases
# 
# 
# NOTE: Module is OPTIONAL - controlled by var.dynamodb_tables

module "dynamodb" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/dynamodb?ref=v1.0.0"

  # General
  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags

  # Encryption
  kms_key_id = module.kms_dynamodb.key_arn

  # Tables configuration
  tables = var.dynamodb_tables

  depends_on = [
    module.kms_dynamodb
  ]

  # DynamoDB features:
  # - Ultra-fast access (< 5 ms latency)
  # - Serverless (pay-per-request)
  # - Auto-scaling (unlimited capacity)
  # - TTL (automatic cleanup)
  # - Encryption at rest (KMS)
  # 
  # Architecture:
  # ECS → DynamoDB (sessions) → < 5 ms response
  # ECS → Redis (cache) → < 1 ms response
  # ECS → RDS (permanent data) → 5-20 ms response
}

# ============================================================================
# MODULE: ELASTICACHE REDIS - Cache Layer
# ============================================================================

# Creates ElastiCache Redis cluster for caching and session storage

module "redis" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/elasticache?ref=v1.0.0"

  # General
  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags

  # Network - Same VPC as Aurora, in private subnets
  subnet_ids = var.private_subnet_ids

  # Security - CHANGED: Use SG from security-groups module
  redis_security_group_id = module.security_groups.redis_security_group_id

  # Redis configuration 
  redis_version          = var.redis_version
  node_type              = var.redis_node_type
  num_cache_nodes        = var.redis_num_cache_nodes
  parameter_group_family = var.redis_parameter_group_family
  port                   = 6379

  automatic_failover_enabled = var.redis_automatic_failover_enabled
  multi_az_enabled           = var.redis_multi_az_enabled

  # Security - Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth_token.result
  kms_key_id                 = module.kms_redis.key_id

  # Backup 
  snapshot_retention_limit = var.redis_snapshot_retention_limit
  snapshot_window          = var.redis_snapshot_window
  maintenance_window       = var.redis_maintenance_window

  # Eviction policy 
  maxmemory_policy = var.redis_maxmemory_policy
  timeout          = var.redis_timeout

  depends_on = [
    module.security_groups, # ← IMPORTANT: Wait for SG to be created
    module.kms_redis
  ]

  # Redis use cases:
  # 1. Query result caching: Reduce RDS load (15x faster)
  # 2. Session storage: Share sessions across ECS tasks
  # 3. Rate limiting: Track API usage per IP/user
  # 4. Real-time counters: Page views, likes, etc.
  # 
  # Connection from ECS:
  # - Endpoint: module.redis.primary_endpoint
  # - Port: 6379
  # - Auth: Stored in Secrets Manager
  # - TLS: Required (transit_encryption_enabled = true)
  # 
  # Performance:
  # - Redis (RAM): < 1 ms response time
  # - RDS (Disk): 5-20 ms response time
  # - Speed gain: 15x faster after first query
  # 
  # Pattern: Cache-Aside (Lazy Loading)
  # 1. App checks Redis
  # 2. If MISS → Query RDS
  # 3. Store result in Redis (TTL = 5 min)
  # 4. Next request → Cache HIT → Return from Redis
}


# ============================================================================
# MODULE: MONITORING - CloudWatch Dashboard & Alarms
# ============================================================================
# Creates CloudWatch monitoring infrastructure:
# - Dashboard with 16 widgets (ALB, ECS, Aurora, Redis)
# - 12 CloudWatch Alarms (6 CRITICAL + 6 WARNING)
# - SNS topic for email notifications
#
# Metrics monitored:
# - ALB: Health, requests, response time, HTTP codes
# - ECS Fargate: CPU, memory, task count
# - Aurora: Connections, CPU, latency, memory
# - Redis: Cache hit rate, evictions, CPU, memory
# ============================================================================

# ============================================================================
# MODULE: SSM PARAMETER STORE - Configuration Management
# ============================================================================
# Stores database configuration in SSM Parameter Store for application access

module "ssm_parameters" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/ssm-parameters?ref=v1.0.0"

  # Naming
  project_name = var.project_name
  environment  = var.environment

  # Encryption
  kms_key_id = module.kms_secrets.key_id # SecureString encryption

  # Database configuration values from Aurora module
  db_writer_endpoint = module.aurora.cluster_endpoint        # Primary endpoint (read/write)
  db_reader_endpoint = module.aurora.cluster_reader_endpoint # Read replica endpoint (read-only)
  db_port            = module.aurora.cluster_port            # Port (5432 or 3306)
  db_name            = var.db_name                           # Database name
  db_username        = var.db_username                       # Master username
  db_secret_arn      = module.db_secret.secret_arn           # Secrets Manager ARN (password)

  tags = merge(
    var.tags,
    { Component = "Configuration" }
  )

  depends_on = [
    module.aurora,
    module.db_secret,
    module.kms_secrets
  ]
}
