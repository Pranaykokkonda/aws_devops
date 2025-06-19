# outputs.tf
output "instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.Java_app_deploy.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.Java_app_deploy.public_ip
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for logs"
  value       = aws_s3_bucket.log_bucket.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.log_bucket.arn
}

output "application_url" {
  description = "URL to access the deployed application"
  value       = "http://${aws_instance.Java_app_deploy.public_ip}:80"
}
