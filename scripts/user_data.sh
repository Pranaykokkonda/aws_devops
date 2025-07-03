#!/bin/bash
# user_data.sh - Enhanced with S3 log upload functionality

set -ex
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

echo "🚀 Starting EC2 setup for stage: ${stage}"
echo "📦 S3 Bucket: ${s3_bucket_name}"

# Install required packages
apt update && apt install -y openjdk-21-jdk maven git awscli

# Create application directory and logs directory
mkdir -p /opt/techeazy-app/logs
mkdir -p /home/ubuntu/app-logs
chmod 755 /opt/techeazy-app/logs
chmod 755 /home/ubuntu/app-logs

cd /home/ubuntu
#git clone ${repo_url}
%{ if use_private_repo }
  echo "🔐 Cloning private repo..."
  git clone https://${github_username}:${github_token}@${replace(repo_url, "https://", "")}
%{ else }
  echo "🌐 Cloning public repo..."
  git clone ${repo_url}
%{ endif }

chown -R ubuntu:ubuntu /home/ubuntu

cd techeazy-devops
chmod +x mvnw

# Build the application with detailed logging
echo "🔨 Building application..."
sudo -u ubuntu ./mvnw clean install > /home/ubuntu/app-logs/build.log 2>&1

# Start the application with proper logging
echo "🚀 Starting Java application..."
nohup java -jar target/techeazy-devops-0.0.1-SNAPSHOT.jar > /home/ubuntu/app-logs/app.log 2>&1 &

# Store the PID for later use
echo $! > /home/ubuntu/app-logs/app.pid

# Create log rotation for application logs
cat > /etc/logrotate.d/techeazy-app << 'EOF'
/home/ubuntu/app-logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF

# Install CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
sudo dpkg -i amazon-cloudwatch-agent.deb

echo "Fetching CloudWatch Agent config..."
curl -o /opt/aws/amazon-cloudwatch-agent/bin/config.json "${cw_agent_config_url}"

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json \
  -s

echo "CloudWatch Agent started with config from ${cw_agent_config_url}"

# Create a shutdown script for log upload
cat > /opt/shutdown-upload.sh << 'SHUTDOWN_SCRIPT'
#!/bin/bash
set -e

BUCKET_NAME="${s3_bucket_name}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

echo "📤 Uploading logs to S3 bucket: $BUCKET_NAME"

# Function to upload logs with error handling
upload_log() {
    local log_file=$1
    local s3_path=$2
    
    if [[ -f "$log_file" ]]; then
        echo "Uploading $log_file to s3://$BUCKET_NAME/$s3_path"
        aws s3 cp "$log_file" "s3://$BUCKET_NAME/$s3_path" || echo "Failed to upload $log_file"
    else
        echo "Log file $log_file not found, skipping..."
    fi
}

# Upload system logs
upload_log "/var/log/cloud-init.log" "logs/system/$INSTANCE_ID/$TIMESTAMP/cloud-init.log"
upload_log "/var/log/cloud-init-output.log" "logs/system/$INSTANCE_ID/$TIMESTAMP/cloud-init-output.log"
upload_log "/var/log/user-data.log" "logs/system/$INSTANCE_ID/$TIMESTAMP/user-data.log"
upload_log "/var/log/syslog" "logs/system/$INSTANCE_ID/$TIMESTAMP/syslog"

# Upload application logs
upload_log "/home/ubuntu/app-logs/build.log" "app/logs/$INSTANCE_ID/$TIMESTAMP/build.log"
upload_log "/home/ubuntu/app-logs/app.log" "app/logs/$INSTANCE_ID/$TIMESTAMP/app.log"

# Upload any additional logs in the app-logs directory
for log_file in /home/ubuntu/app-logs/*.log; do
    if [[ -f "$log_file" ]]; then
        log_basename=$(basename "$log_file")
        upload_log "$log_file" "app/logs/$INSTANCE_ID/$TIMESTAMP/$log_basename"
    fi
done

echo "✅ Log upload completed"
SHUTDOWN_SCRIPT

chmod +x /opt/shutdown-upload.sh

# Create systemd service for shutdown log upload
cat > /etc/systemd/system/log-upload.service << 'SERVICE_FILE'
[Unit]
Description=Upload logs to S3 on shutdown
DefaultDependencies=false
Before=shutdown.target reboot.target halt.target

[Service]
Type=oneshot
RemainAfterExit=true
ExecStart=/bin/true
ExecStop=/opt/shutdown-upload.sh
TimeoutStopSec=300

[Install]
WantedBy=multi-user.target
SERVICE_FILE

# Enable and start the service
systemctl daemon-reload
systemctl enable log-upload.service
systemctl start log-upload.service

# Upload initial logs to S3 (startup logs)
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

echo "📤 Uploading startup logs to S3..."
aws s3 cp /var/log/user-data.log "s3://${s3_bucket_name}/logs/system/$INSTANCE_ID/$TIMESTAMP/startup-user-data.log" || echo "Failed to upload startup logs"

echo "✅ EC2 setup completed successfully!"
echo "🔗 Application should be accessible at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):80"
echo "📁 Logs will be uploaded to S3 bucket: ${s3_bucket_name}"
