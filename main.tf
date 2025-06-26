# main.tf
provider "aws" {
  region = "us-east-1"
}
# EC2 Instance with IAM Instance Profile
resource "aws_instance" "Java_app_deploy" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  vpc_security_group_ids      = ["sg-0a43c58710d9a5d66"]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp2"
  }

  user_data = base64encode(templatefile("scripts/user_data.sh", {
    repo_url       = var.repo_url,
  github_token     = var.github_token,
  github_username  = var.github_username,
  use_private_repo = var.use_private_repo,
    s3_bucket_name = var.s3_bucket_name,
    stage          = var.stage
  }))

  tags = {
    Name = "${var.stage}-JavaAppInstance"
  }
}
