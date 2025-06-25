#!/bin/bash
# deploy.sh - Deployment script using Terraform Workspaces for environment isolation

set -e

STAGE=$1
ACTION=${2:-"deploy"}

if [[ -z "$STAGE" ]]; then
    echo "❌ Please provide a stage (dev or prod)"
    echo "Usage: $0 <stage> [deploy|destroy|verify]"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/${STAGE}_config.tfvars"
PROJECT_ROOT="${SCRIPT_DIR}/.."

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config file $CONFIG_FILE not found!"
    exit 1
fi

S3_BUCKET_NAME=$(grep 's3_bucket_name' "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' "')

if [[ -z "$S3_BUCKET_NAME" ]]; then
    echo "❌ S3 bucket name not found in config file!"
    exit 1
fi

cd "$PROJECT_ROOT"

echo "🚀 Action: $ACTION"
echo "🏷️  Stage: $STAGE"
echo "🔧 Config: $CONFIG_FILE"
echo "📦 S3 Bucket: $S3_BUCKET_NAME"

# Workspace setup
terraform init -input=false
if ! terraform workspace list | grep -qw "$STAGE"; then
    echo "🆕 Creating Terraform workspace: $STAGE"
    terraform workspace new "$STAGE"
fi
terraform workspace select "$STAGE"

case $ACTION in
    "deploy")
        echo "🚀 Deploying infrastructure..."

        if aws s3 ls "s3://$S3_BUCKET_NAME" 2>/dev/null; then
            echo "⚠️  S3 bucket $S3_BUCKET_NAME already exists. Proceeding..."
        else
            echo "✅ S3 bucket name is available"
        fi

        terraform plan -var-file="$CONFIG_FILE" -out=tfplan
        terraform apply -input=false tfplan

        echo "✅ Deployment completed!"

        echo ""
        echo "📋 Deployment Summary:"
        terraform output

        echo ""
        echo "🔗 Application URL:"
        terraform output -raw application_url 2>/dev/null || echo "URL not available"
        ;;

    "verify")
        echo "🔍 Verifying S3 access..."

        if ! terraform show &>/dev/null; then
            echo "❌ No Terraform state found. Please deploy first: $0 $STAGE deploy"
            exit 1
        fi

        # Your existing verify logic (optional)
        ;;

    "destroy")
        echo "💥 Destroying infrastructure for stage: $STAGE"
        read -p "Are you sure? (yes/no): " confirm
        if [[ "$confirm" == "yes" ]]; then
            terraform destroy -var-file="$CONFIG_FILE" -auto-approve
            echo "✅ Destroyed $STAGE environment"
        else
            echo "❌ Destruction cancelled"
        fi
        ;;

    *)
        echo "❌ Invalid action: $ACTION"
        echo "Valid actions: deploy, verify, destroy"
        exit 1
        ;;
esac

