#!/bin/bash
# deploy.sh - Enhanced deployment script with S3 verification and secure handling of AWS credentials

set -e

STAGE=$1
ACTION=${2:-"deploy"}

# Set AWS credentials securely via environment variables
# DO NOT hardcode credentials directly in the script.
# Ensure the following environment variables are set before running the script:
# export AWS_ACCESS_KEY_ID="your-access-key-id"
# export AWS_SECRET_ACCESS_KEY="your-secret-access-key"

if [[ -z "$STAGE" ]]; then
    echo "❌ Please provide a stage (dev or prod or test)"
    echo "Usage: $0 <stage> [deploy|destroy|verify]"
    echo "Examples:"
    echo "  $0 dev deploy    # Deploy infrastructure"
    echo "  $0 dev verify    # Verify S3 access"
    echo "  $0 dev destroy   # Destroy infrastructure"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/${STAGE}_config.tfvars"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config file $CONFIG_FILE not found!"
    exit 1
fi

# Extract S3 bucket name from config file
S3_BUCKET_NAME=$(grep 's3_bucket_name' "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' "')

if [[ -z "$S3_BUCKET_NAME" ]]; then
    echo "❌ S3 bucket name not found in config file!"
    echo "Please ensure s3_bucket_name is configured in $CONFIG_FILE"
    exit 1
fi

echo "🚀 Action: $ACTION"
echo "🏷️  Stage: $STAGE"
echo "🔧 Config: $CONFIG_FILE"
echo "📦 S3 Bucket: $S3_BUCKET_NAME"

cd "$SCRIPT_DIR/.."

case $ACTION in
    "deploy")
        echo "🚀 Deploying infrastructure..."

        # Validate S3 bucket name uniqueness
        echo "🔍 Checking S3 bucket availability..."
        if aws s3 ls "s3://$S3_BUCKET_NAME" 2>/dev/null; then
            echo "⚠️  S3 bucket $S3_BUCKET_NAME already exists. Proceeding with deployment..."
        else
            echo "✅ S3 bucket name is available"
        fi

        # Initialize and apply Terraform
        terraform init
        terraform plan -var-file="$CONFIG_FILE" -out=tfplan
        terraform apply tfplan

        echo "✅ Deployment completed successfully!"

        # Display outputs
        echo ""
        echo "📋 Deployment Summary:"
        terraform output

        echo ""
        echo "🔗 Next steps:"
        echo "1. Wait 2-3 minutes for the application to start"
        echo "2. Access your application at: $(terraform output -raw application_url 2>/dev/null || echo 'Check outputs above')"

        ;;

    "verify")
        echo "🔍 Verifying S3 access permissions..."

        # Check if infrastructure exists
        if ! terraform show &>/dev/null; then
            echo "❌ No Terraform state found. Please deploy first: $0 $STAGE deploy"
            exit 1
        fi

        # Run verification script
        if [[ -f "$SCRIPT_DIR/verify_s3_access.sh" ]]; then
            chmod +x "$SCRIPT_DIR/verify_s3_access.sh"
            "$SCRIPT_DIR/verify_s3_access.sh" "$STAGE" "$S3_BUCKET_NAME"
        else
            echo "⚠️  Verification script not found, running manual checks..."

            # Manual verification
            READONLY_ROLE_ARN=$(terraform output -raw readonly_role_arn 2>/dev/null)

            if [[ -n "$READONLY_ROLE_ARN" ]]; then
                echo "✅ Read-only role ARN: $READONLY_ROLE_ARN"

                # Try to assume role and list bucket
                echo "🔄 Testing read-only access..."
                TEMP_CREDS=$(aws sts assume-role \
                    --role-arn "$READONLY_ROLE_ARN" \
                    --role-session-name "verification-test" \
                    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
                    --output text 2>/dev/null || echo "")

                if [[ -n "$TEMP_CREDS" ]]; then
                    echo "✅ Successfully assumed read-only role"
                    echo "📋 Listing bucket contents..."

                    # Set temporary credentials
                    AWS_ACCESS_KEY_ID=$(echo $TEMP_CREDS | cut -d'\t' -f1)
                    AWS_SECRET_ACCESS_KEY=$(echo $TEMP_CREDS | cut -d'\t' -f2)
                    AWS_SESSION_TOKEN=$(echo $TEMP_CREDS | cut -d'\t' -f3)

                    export AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN

                    aws s3 ls "s3://$S3_BUCKET_NAME" --recursive || echo "Bucket might be empty"

                    # Unset temporary credentials
                    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
                else
                    echo "❌ Failed to assume read-only role"
                fi
            else
                echo "❌ Could not retrieve read-only role ARN"
            fi
        fi
        ;;

    "destroy")
        echo "💥 Destroying infrastructure..."
        echo "⚠️  This will permanently delete all resources!"
        read -p "Are you sure? (yes/no): " confirmation

        if [[ "$confirmation" == "yes" ]]; then
            # Upload any remaining logs before destruction
            INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "")
            if [[ -n "$INSTANCE_ID" ]]; then
                echo "📤 Triggering final log upload..."
                aws ec2 stop-instances --instance-ids "$INSTANCE_ID" || echo "Instance might already be stopped"
                sleep 30  # Wait for shutdown script to upload logs
            fi

            terraform destroy -var-file="$CONFIG_FILE" -auto-approve
            echo "✅ Infrastructure destroyed successfully!"
        else
            echo "🚫 Destruction cancelled"
        fi
        ;;

    *)
        echo "❌ Invalid action: $ACTION"
        echo "Valid actions: deploy, verify, destroy"
        exit 1
        ;;
esac

