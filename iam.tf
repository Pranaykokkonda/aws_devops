# Trust policy for EC2 to assume roles
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Policy that grants Terraform user permissions to create IAM roles, policies and S3 buckets
resource "aws_iam_policy" "terraform_permissions" {
  name        = "terraform-iam-s3-permissions-${var.stage}"
  description = "Permissions for Terraform user to create roles, policies, and S3 buckets[${var.stage}]"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "iam:CreatePolicy",
          "iam:CreateRole",
          "iam:AttachRolePolicy",
          "iam:PutRolePolicy",
          "iam:GetRole",
          "iam:ListAttachedRolePolicies",
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = [
          "s3:CreateBucket",
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to Terraform user
resource "aws_iam_user_policy_attachment" "teraform_user_policy" {
  user       = "teraform"  # Replace with your actual Terraform IAM user
  policy_arn = aws_iam_policy.terraform_permissions.arn
}

# Role 1.a: S3 Read-Only Access Role
resource "aws_iam_role" "s3_readonly_role" {
  name               = "${var.stage}-s3-readonly-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name        = "${var.stage}-s3-readonly-role"
    Environment = var.stage
    Purpose     = "S3 Read-Only Access"
  }
}

# Policy for S3 Read-Only Access
data "aws_iam_policy_document" "s3_readonly_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation"
    ]
    resources = [
      aws_s3_bucket.log_bucket.arn,
      "${aws_s3_bucket.log_bucket.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_readonly_policy" {
  name        = "${var.stage}-s3-readonly-policy"
  description = "Policy for S3 read-only access"
  policy      = data.aws_iam_policy_document.s3_readonly_policy.json
}

resource "aws_iam_role_policy_attachment" "s3_readonly_attachment" {
  role       = aws_iam_role.s3_readonly_role.name
  policy_arn = aws_iam_policy.s3_readonly_policy.arn
}

# Role 1.b: S3 Write-Only Access Role (for EC2 instance)
resource "aws_iam_role" "s3_writeonly_role" {
  name               = "${var.stage}-s3-writeonly-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name        = "${var.stage}-s3-writeonly-role"
    Environment = var.stage
    Purpose     = "S3 Write-Only Access for EC2"
  }
}

# Policy for S3 Write-Only Access (Create bucket, Upload files - NO read/download)
data "aws_iam_policy_document" "s3_writeonly_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:CreateBucket",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.log_bucket.arn,
      "${aws_s3_bucket.log_bucket.arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_writeonly_policy" {
  name        = "${var.stage}-s3-writeonly-policy"
  description = "Policy for S3 write-only access (no read/download)"
  policy      = data.aws_iam_policy_document.s3_writeonly_policy.json
}

resource "aws_iam_role_policy_attachment" "s3_writeonly_attachment" {
  role       = aws_iam_role.s3_writeonly_role.name
  policy_arn = aws_iam_policy.s3_writeonly_policy.arn
}

# Instance Profile for EC2 (attaches write-only role)
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.stage}-ec2-s3-profile"
  role = aws_iam_role.s3_writeonly_role.name

  tags = {
    Name        = "${var.stage}-ec2-s3-profile"
    Environment = var.stage
  }
}

