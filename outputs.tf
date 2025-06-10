# outputs.tf
output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.Java_app_deploy.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.Java_app_deploy.public_ip
}

output "instance_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.Java_app_deploy.public_dns
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for logs"
  value       = aws_s3_bucket.log_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.log_bucket.arn
}

output "readonly_role_arn" {
  description = "ARN of the S3 read-only role"
  value       = aws_iam_role.s3_readonly_role.arn
}

output "writeonly_role_arn" {
  description = "ARN of the S3 write-only role"
  value       = aws_iam_role.s3_writeonly_role.arn
}

output "instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "application_url" {
  description = "URL to access the deployed application"
  value       = "http://${aws_instance.Java_app_deploy.public_ip}:80"
}

output "verification_command" {
  description = "Command to verify S3 access"
  value       = "./verify_s3_access.sh ${var.stage} ${var.s3_bucket_name}"
}
