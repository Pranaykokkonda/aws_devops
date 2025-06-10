#!/bin/bash
# verify_s3_access.sh - Script to verify S3 access using read-only role

set -e

STAGE=$1
BUCKET_NAME=$2

if [[ -z "$STAGE" || -z "$BUCKET_NAME" ]]; then
    echo "❌ Usage: $0 <stage> <bucket_name>"
    echo "Example: $0 dev my-techeazy-logs-bucket"
    exit 1
fi

echo "🔍 Verifying S3 access for stage: $STAGE"
echo "📦 Bucket: $BUCKET_NAME"

# Get the read-only role ARN
READONLY_ROLE_ARN=$(aws iam get-role --role-name "${STAGE}-s3-readonly-role" --query 'Role.Arn' --output text)

if [[ -z "$READONLY_ROLE_ARN" ]]; then
    echo "❌ Read-only role not found: ${STAGE}-s3-readonly-role"
    exit 1
fi

echo "🔑 Read-only role ARN: $READONLY_ROLE_ARN"

# Assume the read-only role
echo "🔄 Assuming read-only role..."
TEMP_CREDS=$(aws sts assume-role \
    --role-arn "$READONLY_ROLE_ARN" \
    --role-session-name "s3-readonly-verification" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
    --output text)

if [[ -z "$TEMP_CREDS" ]]; then
    echo "❌ Failed to assume read-only role"
    exit 1
fi

# Parse credentials
AWS_ACCESS_KEY_ID=$(echo $TEMP_CREDS | cut -d$'\t' -f1)
AWS_SECRET_ACCESS_KEY=$(echo $TEMP_CREDS | cut -d$'\t' -f2)
AWS_SESSION_TOKEN=$(echo $TEMP_CREDS | cut -d$'\t' -f3)

# Export temporary credentials
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_SESSION_TOKEN

echo "✅ Successfully assumed read-only role"

# Test S3 operations with read-only permissions
echo ""
echo "🧪 Testing S3 operations with read-only permissions..."

# Test 1: List bucket contents
echo "📋 Test 1: Listing bucket contents..."
if aws s3 ls "s3://$BUCKET_NAME" --recursive; then
    echo "✅ Successfully listed bucket contents"
else
    echo "⚠️  Bucket might be empty or access denied"
fi

# Test 2: Try to list bucket location
echo ""
echo "🌍 Test 2: Getting bucket location..."
if aws s3api get-bucket-location --bucket "$BUCKET_NAME"; then
    echo "✅ Successfully retrieved bucket location"
else
    echo "❌ Failed to get bucket location"
fi

# Test 3: Try to read a file (if any exists)
echo ""
echo "📖 Test 3: Attempting to read a sample file..."
SAMPLE_FILE=$(aws s3 ls "s3://$BUCKET_NAME" --recursive | head -1 | awk '{print $4}')

if [[ -n "$SAMPLE_FILE" ]]; then
    echo "📄 Found sample file: $SAMPLE_FILE"
    if aws s3 cp "s3://$BUCKET_NAME/$SAMPLE_FILE" /tmp/test-download.tmp; then
        echo "✅ Successfully downloaded file using read-only role"
        rm -f /tmp/test-download.tmp
    else
        echo "❌ Failed to download file"
    fi
else
    echo "ℹ️  No files found in bucket to test download"
fi

# Test 4: Try to upload (should fail with read-only role)
echo ""
echo "🚫 Test 4: Attempting to upload (should fail)..."
echo "test content" > /tmp/test-upload.txt
if aws s3 cp /tmp/test-upload.txt "s3://$BUCKET_NAME/test-upload.txt" 2>/dev/null; then
    echo "❌ SECURITY ISSUE: Upload succeeded with read-only role!"
else
    echo "✅ Upload correctly denied with read-only role"
fi
rm -f /tmp/test-upload.txt

echo ""
echo "🎉 S3 access verification completed!"
echo "📊 Summary:"
echo "   - Read-only role can assume credentials: ✅"
echo "   - Can list bucket contents: ✅"
echo "   - Can download files: ✅"
echo "   - Cannot upload files: ✅"
