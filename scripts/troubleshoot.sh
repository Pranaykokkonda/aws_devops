#!/bin/bash
# troubleshoot.sh - Troubleshooting and cleanup utility

set -e

STAGE=$1
ACTION=$2

show_usage() {
    echo "Usage: $0 <stage> <action>"
    echo ""
    echo "Actions:"
    echo "  check-logs     - Check if logs are being uploaded to S3"
    echo "  test-roles     - Test IAM role permissions"
    echo "  check-app      - Check application status"
    echo "  cleanup-s3     - Clean up old logs from S3"
    echo "  force-upload   - Force upload current logs"
    echo "  debug-instance - Show instance debug information"
    echo ""
    echo "Examples:"
    echo "  $0 dev check-logs"
    echo "  $0 prod test-roles"
}

if [[ -z "$STAGE" || -z "$ACTION" ]]; then
    show_usage
    exit 1
fi

# Get configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/${STAGE}_config.tfvars"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config file $CONFIG_FILE not found!"
    exit 1
fi

S3_BUCKET_NAME=$(grep 's3_bucket_name' "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' "')
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")
INSTANCE_IP=$(terraform output -raw instance_public_ip 2>/dev/null || echo "")

echo "🔧 Troubleshooting for stage: $STAGE"
echo "📦 S3 Bucket: $S3_BUCKET_NAME"
echo "🖥️  Instance ID: $INSTANCE_ID"
echo "🌐 Instance IP: $INSTANCE_IP"
echo ""

case $ACTION in
    "check-logs")
        echo "📋 Checking S3 logs..."
        
        if aws s3 ls "s3://$S3_BUCKET_NAME" &>/dev/null; then
            echo "✅ S3 bucket accessible"
            
            echo ""
            echo "📁 System logs:"
            aws s3 ls "s3://$S3_BUCKET_NAME/logs/system/" --recursive --human-readable || echo "No system logs found"
            
            echo ""
            echo "📁 Application logs:"
            aws s3 ls "s3://$S3_BUCKET_NAME/app/logs/" --recursive --human-readable || echo "No application logs found"
            
            echo ""
            echo "📊 Bucket size:"
            aws s3 ls "s3://$S3_BUCKET_NAME" --recursive --summarize | tail -2
        else
            echo "❌ Cannot access S3 bucket $S3_BUCKET_NAME"
        fi
        ;;
        
    "test-roles")
        echo "🔑 Testing IAM roles..."
        
        # Test read-only role
        READONLY_ROLE_ARN=$(terraform output -raw readonly_role_arn 2>/dev/null || echo "")
        WRITEONLY_ROLE_ARN=$(terraform output -raw writeonly_role_arn 2>/dev/null || echo "")
        
        if [[ -n "$READONLY_ROLE_ARN" ]]; then
            echo "🔍 Testing read-only role: $READONLY_ROLE_ARN"
            
            TEMP_CREDS=$(aws sts assume-role \
                --role-arn "$READONLY_ROLE_ARN" \
                --role-session-name "troubleshoot-readonly" \
                --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
                --output text 2>/dev/null || echo "")
            
            if [[ -n "$TEMP_CREDS" ]]; then
                echo "✅ Can assume read-only role"
                
                # Test with temporary credentials
                AWS_ACCESS_KEY_ID=$(echo $TEMP_CREDS | cut -d$'\t' -f1)
                AWS_SECRET_ACCESS_KEY=$(echo $TEMP_CREDS | cut -d$'\t' -f2)
                AWS_SESSION_TOKEN=$(echo $TEMP_CREDS | cut -d$'\t' -f3)
                
                export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
                
                if aws s3 ls "s3://$S3_BUCKET_NAME" &>/dev/null; then
                    echo "✅ Can list bucket with read-only role"
                else
                    echo "❌ Cannot list bucket with read-only role"
                fi
                
                # Test write (should fail)
                echo "test" > /tmp/test-write.txt
                if aws s3 cp /tmp/test-write.txt "s3://$S3_BUCKET_NAME/test-write.txt" &>/dev/null; then
                    echo "❌ SECURITY ISSUE: Can write with read-only role!"
                else
                    echo "✅ Write correctly denied with read-only role"
                fi
                rm -f /tmp/test-write.txt
                
                unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
            else
                echo "❌ Cannot assume read-only role"
            fi
        else
            echo "❌ Read-only role ARN not found"
        fi
        
        if [[ -n "$WRITEONLY_ROLE_ARN" ]]; then
            echo ""
            echo "📝 Write-only role ARN: $WRITEONLY_ROLE_ARN"
            echo "✅ This role is attached to EC2 instance via instance profile"
        fi
        ;;
        
    "check-app")
        echo "🚀 Checking application status..."
        
        if [[ -n "$INSTANCE_IP" ]]; then
            echo "🌐 Testing application connectivity..."
            
            # Test port 8080
            if curl -s --connect-timeout 5 "http://$INSTANCE_IP:8080" &>/dev/null; then
                echo "✅ Application is responding on port 8080"
                curl -s "http://$INSTANCE_IP:8080" | head -10
            else
                echo "❌ Application not responding on port 8080"
                echo "💡 Try: ssh -i ~/.ssh/your-key.pem ubuntu@$INSTANCE_IP"
                echo "💡 Then check: sudo systemctl status your-app"
            fi
            
            # Test SSH connectivity
            echo ""
            echo "🔐 Testing SSH connectivity..."
            if nc -z -w5 "$INSTANCE_IP" 22 2>/dev/null; then
                echo "✅ SSH port (22) is accessible"
            else
                echo "❌ SSH port (22) not accessible"
            fi
        else
            echo "❌ Instance IP not available"
        fi
        ;;
        
    "cleanup-s3")
        echo "🧹 Cleaning up old logs from S3..."
        
        read -p "This will delete logs older than the configured retention period. Continue? (yes/no): " confirm
        
        if [[ "$confirm" == "yes" ]]; then
            # Force lifecycle policy execution (this is more of a manual cleanup)
            echo "📅 Listing logs older than 7 days..."
            
            CUTOFF_DATE=$(date -d '7 days ago' '+%Y-%m-%d')
            echo "🗓️  Cutoff date: $CUTOFF_DATE"
            
            # List old files
            aws s3api list-objects-v2 --bucket "$S3_BUCKET_NAME" \
                --query "Contents[?LastModified<='$CUTOFF_DATE'].{Key: Key, LastModified: LastModified, Size: Size}" \
                --output table || echo "No old files found or error accessing bucket"
            
            echo "💡 Note: Lifecycle policy will automatically delete these files"
            echo "💡 To force immediate deletion, use AWS CLI with specific prefixes"
        else
            echo "🚫 Cleanup cancelled"
        fi
        ;;
        
    "force-upload")
        echo "📤 Forcing log upload from EC2 instance..."
        
        if [[ -n "$INSTANCE_ID" ]]; then
            echo "🔄 Sending command to upload logs..."
            
            # Create a Systems Manager command to upload logs
            COMMAND_ID=$(aws ssm send-command \
                --instance-ids "$INSTANCE_ID" \
                --document-name "AWS-RunShellScript" \
                --parameters 'commands=["/opt/shutdown-upload.sh"]' \
                --query 'Command.CommandId' \
                --output text 2>/dev/null || echo "")
            
            if [[ -n "$COMMAND_ID" ]]; then
                echo "✅ Command sent: $COMMAND_ID"
                echo "💡 Check command status with: aws ssm get-command-invocation --command-id $COMMAND_ID --instance-id $INSTANCE_ID"
            else
                echo "❌ Failed to send command via Systems Manager"
                echo "💡 Try SSH method: ssh -i ~/.ssh/your-key.pem ubuntu@$INSTANCE_IP"
                echo "💡 Then run: sudo /opt/shutdown-upload.sh"
            fi
        else
            echo "❌ Instance ID not available"
        fi
        ;;
        
    "debug-instance")
        echo "🐛 Instance debug information..."
        
        if [[ -n "$INSTANCE_ID" ]]; then
            echo "📊 Instance details:"
            aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
                --query 'Reservations[0].Instances[0].{State:State.Name,Type:InstanceType,LaunchTime:LaunchTime,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress}' \
                --output table || echo "Failed to get instance details"
            
            echo ""
            echo "🔒 Security groups:"
            aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
                --query 'Reservations[0].Instances[0].SecurityGroups[*].{GroupName:GroupName,GroupId:GroupId}' \
                --output table || echo "Failed to get security groups"
            
            echo ""
            echo "🏷️  Instance tags:"
            aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
                --query 'Reservations[0].Instances[0].Tags[*].{Key:Key,Value:Value}' \
                --output table || echo "Failed to get instance tags"
            
            echo ""
            echo "📋 Instance profile:"
            aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
                --query 'Reservations[0].Instances[0].IamInstanceProfile.Arn' \
                --output text || echo "No instance profile attached"
                
            echo ""
            echo "📝 Recent console output (last 50 lines):"
            aws ec2 get-console-output --instance-id "$INSTANCE_ID" \
                --query 'Output' --output text 2>/dev/null | tail -50 || echo "Console output not available"
        else
            echo "❌ Instance ID not available"
        fi
        ;;
        
    *)
        echo "❌ Unknown action: $ACTION"
        show_usage
        exit 1
        ;;
esac

echo ""
echo "✅ Troubleshooting completed for action: $ACTION"
