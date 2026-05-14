# ============================================================================
# MODULE: MONITORING - Centralized CloudWatch Monitoring
# ============================================================================
# Dashboard widgets remain local to the blueprint as a JSON template while
# alarm definitions are expressed in HCL for readability and reuse.
# ============================================================================

locals {
  monitoring_dashboard_body = templatefile("${path.module}/../../monitoring/dashboard.json.tftpl", {
    region                     = var.region
    alb_arn_suffix             = module.alb.alb_arn_suffix
    target_group_arn_suffix    = module.alb.target_group_arn_suffix
    ecs_cluster_name           = module.ecs.cluster_name
    ecs_service_name           = module.ecs.service_name
    db_cluster_id              = module.aurora.cluster_id
    db_connections_threshold   = var.database_connection_threshold
    redis_replication_group_id = module.redis.replication_group_id
  })

  monitoring_alarm_definitions = {
    alb_unhealthy_targets = {
      alarm_name          = "${var.project_name}-${var.environment}-alb-unhealthy-targets"
      alarm_description   = "CRITICAL: Unhealthy targets detected - application may be down"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "UnHealthyHostCount"
      namespace           = "AWS/ApplicationELB"
      period              = 300
      statistic           = "Average"
      threshold           = var.monitoring_unhealthy_target_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        LoadBalancer = module.alb.alb_arn_suffix
        TargetGroup  = module.alb.target_group_arn_suffix
      }
      tags = {
        Name     = "${var.project_name}-${var.environment}-alb-unhealthy-targets"
        Severity = "CRITICAL"
      }
    }

    alb_5xx_errors = {
      alarm_name          = "${var.project_name}-${var.environment}-alb-5xx-errors"
      alarm_description   = "CRITICAL: High rate of 5xx errors - application errors detected"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 1
      metric_name         = "HTTPCode_Target_5XX_Count"
      namespace           = "AWS/ApplicationELB"
      period              = 300
      statistic           = "Sum"
      threshold           = var.monitoring_alb_5xx_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        LoadBalancer = module.alb.alb_arn_suffix
      }
      tags = {
        Name     = "${var.project_name}-${var.environment}-alb-5xx-errors"
        Severity = "CRITICAL"
      }
    }

    ecs_task_count_low = {
      alarm_name          = "${var.project_name}-${var.environment}-ecs-task-count-low"
      alarm_description   = "CRITICAL: Running task count below desired - tasks are crashing"
      comparison_operator = "LessThanThreshold"
      evaluation_periods  = 2
      metric_name         = "RunningTaskCount"
      namespace           = "ECS/ContainerInsights"
      period              = 300
      statistic           = "Average"
      threshold           = 1
      treat_missing_data  = "breaching"
      dimensions = {
        ServiceName = module.ecs.service_name
        ClusterName = module.ecs.cluster_name
      }
      tags = {
        Name     = "${var.project_name}-${var.environment}-ecs-task-count-low"
        Severity = "CRITICAL"
      }
    }

    aurora_high_connections = {
      alarm_name          = "${var.project_name}-${var.environment}-aurora-high-connections"
      alarm_description   = "CRITICAL: Database connections near maximum - connection pool exhaustion risk"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "DatabaseConnections"
      namespace           = "AWS/RDS"
      period              = 300
      statistic           = "Average"
      threshold           = var.database_connection_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        DBClusterIdentifier = module.aurora.cluster_id
      }
      tags = {
        Name     = "${var.project_name}-${var.environment}-aurora-high-connections"
        Severity = "CRITICAL"
      }
    }

    redis_low_cache_hit_rate = {
      alarm_name          = "${var.project_name}-${var.environment}-redis-low-cache-hit-rate"
      alarm_description   = "CRITICAL: Redis cache hit rate below threshold - cache ineffective, Aurora overload risk"
      comparison_operator = "LessThanThreshold"
      evaluation_periods  = 3
      metric_name         = "CacheHitRate"
      namespace           = "AWS/ElastiCache"
      period              = 300
      statistic           = "Average"
      threshold           = var.monitoring_redis_cache_hit_rate_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        ReplicationGroupId = module.redis.replication_group_id
      }
      tags = {
        Name     = "${var.project_name}-${var.environment}-redis-low-cache-hit-rate"
        Severity = "CRITICAL"
      }
    }

    redis_high_evictions = {
      alarm_name          = "${var.project_name}-${var.environment}-redis-high-evictions"
      alarm_description   = "CRITICAL: Redis evictions high - insufficient memory, cache data loss"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 2
      metric_name         = "Evictions"
      namespace           = "AWS/ElastiCache"
      period              = 300
      statistic           = "Sum"
      threshold           = var.monitoring_redis_evictions_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        ReplicationGroupId = module.redis.replication_group_id
      }
      tags = {
        Name     = "${var.project_name}-${var.environment}-redis-high-evictions"
        Severity = "CRITICAL"
      }
    }

    alb_high_response_time = {
      alarm_name          = "${var.project_name}-${var.environment}-alb-high-response-time"
      alarm_description   = "WARNING: ALB response time elevated - application performance degraded"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
      metric_name         = "TargetResponseTime"
      namespace           = "AWS/ApplicationELB"
      period              = 300
      statistic           = "Average"
      threshold           = var.monitoring_alb_response_time_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        LoadBalancer = module.alb.alb_arn_suffix
      }
      tags = {
        Name     = "${var.project_name}-${var.environment}-alb-high-response-time"
        Severity = "WARNING"
      }
    }

    ecs_high_cpu = {
      alarm_name          = "${var.project_name}-${var.environment}-ecs-high-cpu"
      alarm_description   = "WARNING: ECS task CPU utilization high - consider scaling up"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
      metric_name         = "CPUUtilization"
      namespace           = "AWS/ECS"
      period              = 300
      statistic           = "Average"
      threshold           = var.monitoring_ecs_cpu_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        ServiceName = module.ecs.service_name
        ClusterName = module.ecs.cluster_name
      }
      tags = {
        Name     = "${var.project_name}-${var.environment}-ecs-high-cpu"
        Severity = "WARNING"
      }
    }

    ecs_high_memory = {
      alarm_name          = "${var.project_name}-${var.environment}-ecs-high-memory"
      alarm_description   = "WARNING: ECS task memory utilization high - consider scaling up"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
      metric_name         = "MemoryUtilization"
      namespace           = "AWS/ECS"
      period              = 300
      statistic           = "Average"
      threshold           = var.monitoring_ecs_memory_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        ServiceName = module.ecs.service_name
        ClusterName = module.ecs.cluster_name
      }
      tags = {
        Name     = "${var.project_name}-${var.environment}-ecs-high-memory"
        Severity = "WARNING"
      }
    }

    aurora_high_cpu = {
      alarm_name          = "${var.project_name}-${var.environment}-aurora-high-cpu"
      alarm_description   = "WARNING: Aurora CPU utilization high - database overloaded"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
      metric_name         = "CPUUtilization"
      namespace           = "AWS/RDS"
      period              = 300
      statistic           = "Average"
      threshold           = var.monitoring_db_cpu_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        DBClusterIdentifier = module.aurora.cluster_id
      }
      tags = {
        Name     = "${var.project_name}-${var.environment}-aurora-high-cpu"
        Severity = "WARNING"
      }
    }

    aurora_high_read_latency = {
      alarm_name          = "${var.project_name}-${var.environment}-aurora-high-read-latency"
      alarm_description   = "WARNING: Aurora read latency elevated - queries slow"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
      metric_name         = "ReadLatency"
      namespace           = "AWS/RDS"
      period              = 300
      statistic           = "Average"
      threshold           = var.monitoring_db_read_latency_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        DBClusterIdentifier = module.aurora.cluster_id
      }
      tags = {
        Name     = "${var.project_name}-${var.environment}-aurora-high-read-latency"
        Severity = "WARNING"
      }
    }

    redis_high_cpu = {
      alarm_name          = "${var.project_name}-${var.environment}-redis-high-cpu"
      alarm_description   = "WARNING: Redis CPU utilization high - cache overloaded"
      comparison_operator = "GreaterThanThreshold"
      evaluation_periods  = 3
      metric_name         = "CPUUtilization"
      namespace           = "AWS/ElastiCache"
      period              = 300
      statistic           = "Average"
      threshold           = var.monitoring_redis_cpu_threshold
      treat_missing_data  = "notBreaching"
      dimensions = {
        ReplicationGroupId = module.redis.replication_group_id
      }
      tags = {
        Name     = "${var.project_name}-${var.environment}-redis-high-cpu"
        Severity = "WARNING"
      }
    }
  }
}

module "monitoring" {
  source = "git::ssh://your-alert-email@example.com/a-grivet/terraform-modules-aws-aws.git//modules/monitoring?ref=v1.0.0"

  project_name = var.project_name
  environment  = var.environment
  alert_email  = var.alert_email

  dashboard_body    = local.monitoring_dashboard_body
  alarm_definitions = local.monitoring_alarm_definitions

  tags = merge(
    var.tags,
    { Component = "Monitoring" }
  )

  depends_on = [
    module.alb,
    module.ecs,
    module.aurora,
    module.redis
  ]
}
