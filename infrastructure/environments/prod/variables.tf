# ============================================================================
# TERRAFORM VARIABLES DEFINITION FILE (variables.tf)
# ============================================================================
# This file DEFINES what variables exist and their properties (type, default, description).
# Think of this as a "contract" or "template" that specifies what inputs your Terraform
# configuration accepts.
#
# The VALUES for these variables are set in terraform.tfvars.
#
# 🔴 CRITICAL variables (no default) = MUST provide in terraform.tfvars
# 🟡 IMPORTANT variables (with defaults) = CAN override in terraform.tfvars
#
# Variables without a default value MUST be provided in terraform.tfvars.
# Variables that gave a default value and that are set in terraform.tfvars are overrited by value in terraform.tfvars
# ============================================================================

# ============================================================================
# GENERAL VARIABLES
# ============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  # No default = REQUIRED variable (must be set in terraform.tfvars)
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
  # No default = REQUIRED variable
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"  # Default value if not specified in terraform.tfvars 
}

# ============================================================================
# NETWORKING VARIABLES (Pre-existing infrastructure)
# ============================================================================
# These variables reference network resources that already exist in AWS

variable "vpc_id" {
  description = "Existing VPC ID"
  type        = string
  # No default = REQUIRED variable
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for NAT Gateways"
  type        = list(string)  # list(string) = array of text values
  # No default = REQUIRED variable
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
  # No default = REQUIRED variable
}

# ============================================================================
# APPLICATION PORT CONFIGURATION - 🔴 CRITICAL
# ============================================================================

variable "app_port" {
  description = "Port the application listens on (used for security groups and ALB target group)"
  type        = number
  # 🔴 NO DEFAULT - User MUST provide
  # Examples: 80 (nginx), 3000 (Node.js), 8080 (Java), 5000 (Flask)
}

# ============================================================================
# DNS & SSL/TLS CERTIFICATE VARIABLES
# ============================================================================
# These variables configure your custom domain and HTTPS certificate

variable "domain_name" {
  description = "Domain name for the application (e.g., app.dev.your-org.com)"
  type        = string
  # No default = REQUIRED variable
}

variable "zone_name" {
  description = "Route53 hosted zone name (e.g., your-org.com)"
  type        = string
  # No default = REQUIRED variable
}

variable "zone_id" {
  description = "Route53 Hosted Zone ID (optional, use instead of zone_name for delegated zones)"
  type        = string
  default     = ""  # Empty string = use zone_name to look up the zone
}

variable "enable_certificate_monitoring" {
  description = "Enable certificate expiry monitoring"
  type        = bool  # Boolean: true or false
  default     = false  # Disabled by default (enable in prod for alerts)
}

# ============================================================================
# ALB CONFIGURATION
# ============================================================================

variable "target_type" {
  description = "Type of target (instance, ip, or lambda)"
  type        = string
}

variable "alb_ssl_policy" {
  description = "SSL/TLS policy for HTTPS listener"
  type        = string
  default     = "ELBSecurityPolicy-TLS-1-2-2017-01"
  # TLS 1.2 minimum (secure)
}

variable "alb_deregistration_delay" {
  description = "Time in seconds before deregistering target"
  type        = number
  default     = 30
  # Dev: 30s (fast), Prod: 300s (graceful)
}

# ===== HEALTH CHECK CONFIGURATION =====

variable "health_check_path" {
  description = "Health check endpoint path"
  type        = string
  # 🔴 NO DEFAULT - User MUST provide
  # Examples: "/health", "/healthz", "/api/health", "/"
}

variable "health_check_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "health_check_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 10
}

variable "health_check_healthy_threshold" {
  description = "Number of consecutive successful checks to mark target healthy"
  type        = number
  default     = 3
}

variable "health_check_unhealthy_threshold" {
  description = "Number of consecutive failed checks to mark target unhealthy"
  type        = number
  default     = 3
}

variable "health_check_matcher" {
  description = "HTTP status codes to consider healthy"
  type        = string
  default     = "200"
  # Examples: "200", "200,202", "200-299"
}

# ============================================================================
# ECR (ELASTIC CONTAINER REGISTRY) VARIABLES
# ============================================================================

variable "ecr_image_tag_mutability" {
  description = "Image tag mutability: MUTABLE (dev) or IMMUTABLE (prod)"
  type        = string
  default     = "MUTABLE"
  
  # Development uses MUTABLE for fast iteration
  # Production should use IMMUTABLE for security
}

variable "ecr_scan_on_push" {
  description = "Enable automatic vulnerability scanning on image push"
  type        = bool
  default     = true
  
  # Always enabled for security best practices
}

variable "ecr_max_image_count" {
  description = "Maximum number of images to retain in ECR (lifecycle policy)"
  type        = number
  default     = 5
  
  # Dev: Keep fewer images (5)
  # Prod: Keep more images (20-30) for rollback capability
}

variable "ecr_untagged_days" {
  description = "Days to retain untagged images before deletion"
  type        = number
  default     = 1
  
  # Dev: Aggressive cleanup (1 day)
  # Prod: Conservative cleanup (7-14 days)
}

variable "ecr_encryption_type" {
  description = "Encryption type for ECR (AES256 or KMS)"
  type        = string
  default     = "AES256"
  # AES256 = AWS-managed, KMS = Customer-managed
}

# ============================================================================
# ECS FARGATE CONFIGURATION - 🔴 CRITICAL
# ============================================================================

variable "container_name" {
  description = "Name of the container in the task definition"
  type        = string
  default     = "app"
}

variable "container_image" {
  description = "Docker image to use (nginx:latest for initial deployment, then your ECR image)"
  type        = string
  # 🔴 NO DEFAULT - User MUST provide
}

variable "container_port" {
  description = "Port the container listens on"
  type        = number
  # 🔴 NO DEFAULT - User MUST provide
}

variable "task_cpu" {
  description = "Task CPU units (256, 512, 1024, 2048, 4096)"
  type        = number
  # 🔴 NO DEFAULT - User MUST provide
}

variable "task_memory" {
  description = "Task memory in MB (must be compatible with task_cpu)"
  type        = number
  # 🔴 NO DEFAULT - User MUST provide
}

variable "ecs_desired_count" {
  description = "Number of ECS tasks to run"
  type        = number
  # 🔴 NO DEFAULT - User MUST provide
}

variable "ecs_deployment_min_healthy_percent" {
  description = "Minimum healthy percent during deployment"
  type        = number
  default     = 50
  # Dev: 50 (faster), Prod: 100 (zero downtime)
}

variable "ecs_deployment_max_percent" {
  description = "Maximum percent during deployment"
  type        = number
  default     = 200
}

variable "ecs_enable_circuit_breaker" {
  description = "Enable deployment circuit breaker"
  type        = bool
  default     = true
}

variable "ecs_enable_execute_command" {
  description = "Enable ECS Exec for debugging"
  type        = bool
  default     = false
}

variable "ecs_log_retention_days" {
  description = "CloudWatch Logs retention in days"
  type        = number
  default     = 7
  # Dev: 7, Prod: 30
}

variable "ecs_enable_container_insights" {
  description = "Enable CloudWatch Container Insights"
  type        = bool
  default     = true
}

# ============================================================================
# DATABASE VARIABLES (Aurora)
# ============================================================================
# Aurora is AWS's managed relational database with automatic failover

variable "db_engine" {
  description = "Database engine (aurora-postgresql or aurora-mysql)"
  type        = string
  default     = "aurora-postgresql"  # PostgreSQL-compatible Aurora
}

variable "db_engine_version" {
  description = "Database engine version"
  type        = string
  # No default = REQUIRED variable (DB engine version)
}

variable "db_name" {
  description = "Database name"
  type        = string
  # No default = REQUIRED variable (the name of the database to create)
}

variable "db_username" {
  description = "Database master username"
  type        = string
  # No default = REQUIRED variable (admin username for database access)
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432  # PostgreSQL default port
  # Use 3306 for MySQL
}

variable "db_instance_class" {
  description = "Database instance class"
  type        = string
  default     = "db.t3.medium"  # Medium instance size (2 vCPU, 4GB RAM)
}

variable "db_writer_instances" {
  description = "Number of writer instances"
  type        = number
  default     = 1  # Typically 1 writer instance (handles all write operations)
}

variable "db_reader_instances" {
  description = "Number of reader instances"
  type        = number
  default     = 1  # Reader instances handle read queries (improves performance)
  # Scale readers up for read-heavy workloads
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7  # Keep automated backups for 7 days
  # Increase for production (e.g., 30 days)
}

variable "db_backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "03:00-04:00"  # UTC time (1-hour window during low-traffic period)
}

variable "db_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"  # UTC time (Sunday, 1-hour window)
  # AWS may apply patches or updates during this window
}

variable "db_monitoring_interval" {
  description = "Enhanced monitoring interval in seconds (0 = disabled, 1, 5, 10, 15, 30, 60)"
  type        = number
  default     = 0
  # Dev: 0 (disabled), Prod: 60 (1 minute)
}

variable "db_performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

# ============================================================================
# REDIS CONFIGURATION - 🔴 CRITICAL
# ============================================================================

variable "redis_version" {
  description = "Redis engine version"
  type        = string
  default     = "7.1"
}

variable "redis_node_type" {
  description = "Instance type for Redis nodes"
  type        = string
  # 🔴 NO DEFAULT - User MUST provide
  # Examples: cache.t3.micro (dev), cache.r6g.large (prod)
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes (1 = no HA, 2+ = HA with replicas)"
  type        = number
  # 🔴 NO DEFAULT - User MUST provide
  # Dev: 1, Prod: 2+
}

variable "redis_parameter_group_family" {
  description = "Redis parameter group family"
  type        = string
  default     = "redis7"
}

variable "redis_automatic_failover_enabled" {
  description = "Enable automatic failover (requires num_cache_nodes >= 2)"
  type        = bool
  default     = false
  # Dev: false, Prod: true
}

variable "redis_multi_az_enabled" {
  description = "Enable Multi-AZ deployment"
  type        = bool
  default     = false
  # Dev: false, Prod: true
}

variable "redis_snapshot_retention_limit" {
  description = "Number of days to retain automatic snapshots"
  type        = number
  default     = 1
  # Dev: 1, Prod: 7+
}

variable "redis_snapshot_window" {
  description = "Daily time range for automated backups (UTC)"
  type        = string
  default     = "03:00-05:00"
}

variable "redis_maintenance_window" {
  description = "Weekly time range for maintenance (UTC)"
  type        = string
  default     = "sun:05:00-sun:07:00"
}

variable "redis_maxmemory_policy" {
  description = "Eviction policy when maxmemory is reached"
  type        = string
  default     = "allkeys-lru"
}

variable "redis_timeout" {
  description = "Close idle client connections after N seconds"
  type        = number
  default     = 300
}

# ============================================================================
# DYNAMODB CONFIGURATION
# ============================================================================

variable "dynamodb_tables" {
  description = "DynamoDB tables configuration (optional - empty by default)"
  type = map(object({
    billing_mode           = string
    hash_key               = string
    hash_key_type          = string
    range_key              = optional(string)
    range_key_type         = optional(string)
    ttl_enabled            = optional(bool, false)
    ttl_attribute_name     = optional(string)
    point_in_time_recovery = optional(bool, true)
    
    # DynamoDB Streams (for event-driven architectures, Lambda triggers)
    stream_enabled   = optional(bool, false)
    stream_view_type = optional(string, "NEW_AND_OLD_IMAGES")  # KEYS_ONLY, NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES
    
    global_secondary_indexes = optional(list(object({
      name               = string
      hash_key           = string
      hash_key_type      = string
      range_key          = optional(string)
      range_key_type     = optional(string)
      projection_type    = string
      non_key_attributes = optional(list(string))
    })), [])
    
    local_secondary_indexes = optional(list(object({
      name            = string
      range_key       = string
      range_key_type  = string
      projection_type = string
      non_key_attributes = optional(list(string))
    })), [])
  }))
  
  default = {}
  # Empty = No DynamoDB tables (disabled by default)
}

# ============================================================================
# SECRETS MANAGER CONFIGURATION
# ============================================================================

variable "secrets_password_length" {
  description = "Length of auto-generated passwords"
  type        = number
  default     = 32
}

variable "secrets_recovery_window_days" {
  description = "Recovery window for deleted secrets in days"
  type        = number
  default     = 7
  # Dev: 7, Prod: 30
}

# ============================================================================
# IAM (Identity and Access Management) VARIABLES
# ============================================================================
# IAM controls who/what can access AWS resources and what actions they can perform

  variable "permissions_boundary_arn" {
  description = "ARN of the IAM Permissions Boundary to attach to the IAM Role."
  type        = string
  # Permissions boundary: A security control that sets the maximum permissions
  # a role can have, even if more permissive policies are attached
  default     = "arn:aws:iam::670943688569:policy/OrgPermissionBoundary" # Your Organization default permission boundary
  }

# ============================================================================
# MONITORING CONFIGURATION VARIABLES
# ============================================================================
# These variables configure CloudWatch alarms and notifications

variable "alert_email" {
  description = "Email address to receive CloudWatch alarm notifications"
  type        = string
  # No default = REQUIRED variable (where to send alerts)
  # Note: You'll need to confirm the email subscription when first created
}

variable "database_connection_threshold" {
  description = "Threshold for Aurora database connections alarm"
  type        = number
  default     = 80  # Alert if database connections exceed 80
  # Adjust based on your db_instance_class (each class has max connection limits)
}

# ===== MONITORING THRESHOLDS =====

variable "monitoring_unhealthy_target_threshold" {
  description = "ALB unhealthy target threshold"
  type        = number
  default     = 0
}

variable "monitoring_alb_5xx_threshold" {
  description = "ALB 5xx errors threshold"
  type        = number
  default     = 10
}

variable "monitoring_alb_response_time_threshold" {
  description = "ALB response time threshold in seconds"
  type        = number
  default     = 1.0
}

variable "monitoring_ecs_cpu_threshold" {
  description = "ECS CPU utilization threshold"
  type        = number
  default     = 80
}

variable "monitoring_ecs_memory_threshold" {
  description = "ECS memory utilization threshold"
  type        = number
  default     = 80
}

variable "monitoring_db_cpu_threshold" {
  description = "Aurora CPU utilization threshold"
  type        = number
  default     = 85
}

variable "monitoring_db_read_latency_threshold" {
  description = "Aurora read latency threshold in seconds"
  type        = number
  default     = 0.1
}

variable "monitoring_redis_cache_hit_rate_threshold" {
  description = "Redis cache hit rate threshold"
  type        = number
  default     = 80
}

variable "monitoring_redis_evictions_threshold" {
  description = "Redis evictions threshold"
  type        = number
  default     = 100
}

variable "monitoring_redis_cpu_threshold" {
  description = "Redis CPU utilization threshold"
  type        = number
  default     = 70
}

variable "monitoring_redis_memory_threshold" {
  description = "Redis memory usage threshold"
  type        = number
  default     = 90
}

# ============================================================================
# TAGS VARIABLE
# ============================================================================
# Tags are key-value pairs for organizing and tracking AWS resources

variable "tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)  # map(string) = dictionary/object with string values
  default     = {}  # Empty map = no tags by default
  # Tags are typically provided in terraform.tfvars and applied to all resources
}
