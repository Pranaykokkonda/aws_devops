# s3.tf - S3 Bucket Configuration

# Private S3 Bucket for Log Storage
resource "aws_s3_bucket" "log_bucket" {
  bucket = var.s3_bucket_name

  tags = {
    Name        = var.s3_bucket_name
    Environment = var.stage
    Purpose     = "Log Storage and Archival"
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "log_bucket_pab" {
  bucket = aws_s3_bucket.log_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bucket versioning
resource "aws_s3_bucket_versioning" "log_bucket_versioning" {
  bucket = aws_s3_bucket.log_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "log_bucket_encryption" {
  bucket = aws_s3_bucket.log_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Combined Lifecycle configuration (only one allowed per bucket)
resource "aws_s3_bucket_lifecycle_configuration" "log_bucket_lifecycle" {
  bucket = aws_s3_bucket.log_bucket.id

  depends_on = [
    aws_s3_bucket.log_bucket,
    aws_s3_bucket_versioning.log_bucket_versioning,
    aws_s3_bucket_server_side_encryption_configuration.log_bucket_encryption,
    aws_s3_bucket_public_access_block.log_bucket_pab
  ]

  rule {
    id     = "delete_logs_after_${var.log_retention_days}_days"
    status = "Enabled"

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.log_retention_days
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }

    filter {
      prefix = "logs/"
    }
  }

  rule {
    id     = "delete_app_logs_after_${var.log_retention_days}_days"
    status = "Enabled"

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = var.log_retention_days
    }

    filter {
      prefix = "app/logs/"
    }
  }
}
