#!/bin/bash
# ============================================================================
# ENTRYPOINT SCRIPT - Generate Dynamic HTML Page
# ============================================================================
# This script runs when the container starts and does the following:
# 1. Fetches ECS task metadata from the ECS metadata endpoint
# 2. Extracts useful information (Task ID, IP, AZ, etc.)
# 3. Generates an HTML page showing "Hello from <Task ID>"
# 4. Starts nginx to serve the page
#
# ECS Fargate provides metadata via environment variable:
# - ECS_CONTAINER_METADATA_URI_V4: endpoint to fetch task metadata
# ============================================================================

set -e  # Exit on error

echo "=========================================="
echo "🚀 Starting ECS Demo Application"
echo "=========================================="

# ============================================================================
# FETCH ECS METADATA
# ============================================================================

# Check if running in ECS (metadata endpoint is available)
if [ -n "$ECS_CONTAINER_METADATA_URI_V4" ]; then
    echo "✅ Running in ECS Fargate - Fetching metadata..."
    
    # Fetch task metadata from ECS metadata endpoint
    METADATA=$(curl -s "${ECS_CONTAINER_METADATA_URI_V4}/task" || echo "{}")
    
    # Extract useful information using jq
    TASK_ARN=$(echo "$METADATA" | jq -r '.TaskARN // "unknown"')
    TASK_ID=$(echo "$TASK_ARN" | awk -F'/' '{print $NF}' | cut -c1-8)
    AVAILABILITY_ZONE=$(echo "$METADATA" | jq -r '.AvailabilityZone // "unknown"')
    CLUSTER=$(echo "$METADATA" | jq -r '.Cluster // "unknown"' | awk -F'/' '{print $NF}')
    
    # Get container IP from container metadata
    CONTAINER_METADATA=$(curl -s "${ECS_CONTAINER_METADATA_URI_V4}" || echo "{}")
    CONTAINER_IP=$(echo "$CONTAINER_METADATA" | jq -r '.Networks[0].IPv4Addresses[0] // "unknown"')
    
    echo "📋 Task ARN: $TASK_ARN"
    echo "🆔 Task ID: $TASK_ID"
    echo "🌍 Availability Zone: $AVAILABILITY_ZONE"
    echo "🔗 Cluster: $CLUSTER"
    echo "📡 Container IP: $CONTAINER_IP"
else
    echo "⚠️  Not running in ECS - Using default values"
    TASK_ID="local-container"
    AVAILABILITY_ZONE="local"
    CLUSTER="local"
    CONTAINER_IP=$(hostname -i || echo "127.0.0.1")
fi

# ============================================================================
# GENERATE HTML PAGE
# ============================================================================

echo "📝 Generating HTML page..."

cat > /usr/share/nginx/html/index.html << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ECS Fargate Demo</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 20px;
        }
        
        .container {
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            padding: 40px;
            max-width: 600px;
            width: 100%;
            animation: fadeIn 0.5s ease-in;
        }
        
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(20px); }
            to { opacity: 1; transform: translateY(0); }
        }
        
        h1 {
            color: #667eea;
            font-size: 2.5em;
            margin-bottom: 10px;
            text-align: center;
        }
        
        .task-id {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            font-weight: bold;
            font-size: 1.2em;
        }
        
        .subtitle {
            text-align: center;
            color: #666;
            margin-bottom: 30px;
            font-size: 1.1em;
        }
        
        .metadata {
            background: #f7f7f7;
            border-radius: 10px;
            padding: 20px;
            margin-top: 30px;
        }
        
        .metadata h2 {
            color: #333;
            font-size: 1.3em;
            margin-bottom: 15px;
            border-bottom: 2px solid #667eea;
            padding-bottom: 10px;
        }
        
        .info-row {
            display: flex;
            justify-content: space-between;
            padding: 10px 0;
            border-bottom: 1px solid #e0e0e0;
        }
        
        .info-row:last-child {
            border-bottom: none;
        }
        
        .info-label {
            font-weight: bold;
            color: #555;
        }
        
        .info-value {
            color: #667eea;
            font-family: 'Courier New', monospace;
        }
        
        .footer {
            text-align: center;
            margin-top: 30px;
            color: #999;
            font-size: 0.9em;
        }
        
        .badge {
            display: inline-block;
            background: #667eea;
            color: white;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.9em;
            margin-top: 10px;
        }
        
        .refresh-btn {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            border: none;
            padding: 12px 30px;
            border-radius: 25px;
            font-size: 1em;
            cursor: pointer;
            margin-top: 20px;
            width: 100%;
            transition: transform 0.2s;
        }
        
        .refresh-btn:hover {
            transform: scale(1.05);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>👋 Hello from</h1>
        <p class="subtitle">
            ECS Task: <span class="task-id">$TASK_ID</span>
        </p>
        
        <div class="metadata">
            <h2>📊 Task Metadata</h2>
            
            <div class="info-row">
                <span class="info-label">Task ID:</span>
                <span class="info-value">$TASK_ID</span>
            </div>
            
            <div class="info-row">
                <span class="info-label">Container IP:</span>
                <span class="info-value">$CONTAINER_IP</span>
            </div>
            
            <div class="info-row">
                <span class="info-label">Availability Zone:</span>
                <span class="info-value">$AVAILABILITY_ZONE</span>
            </div>
            
            <div class="info-row">
                <span class="info-label">ECS Cluster:</span>
                <span class="info-value">$CLUSTER</span>
            </div>
            
            <div class="info-row">
                <span class="info-label">Timestamp:</span>
                <span class="info-value">$(date '+%Y-%m-%d %H:%M:%S %Z')</span>
            </div>
        </div>
        
        <button class="refresh-btn" onclick="location.reload()">
            🔄 Refresh Page
        </button>
        
        <div class="footer">
            <span class="badge">ECS Fargate</span>
            <span class="badge">AWS ALB</span>
            <span class="badge">Aurora</span>
            <span class="badge">Elasticache REDIS</span>
            <span class="badge">Terraform</span>
            <p style="margin-top: 15px;">
                Cloud Adoption<br>
                Blueprint: ECS Standalone
            </p>
        </div>
    </div>
</body>
</html>
EOF

echo "✅ HTML page generated successfully"

# ============================================================================
# START NGINX
# ============================================================================

echo "🚀 Starting nginx..."
echo "=========================================="

# Start nginx in foreground mode
exec nginx -g 'daemon off;'
