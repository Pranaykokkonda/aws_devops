# Simple Java Application Deployment using Terraform🟪	 Infrastructure🛠️🌍 With S3 Log Management
This Terraform configuration deploys a Java application on AWS EC2 with comprehensive S3 log management, IAM roles, and automated log archival.

## 🏗️ Architecture Overview
## Infrastructure Components

VPC & Networking: Custom VPC with public subnet, internet gateway, and routing
EC2 Instance: Ubuntu instance with Java 21, Maven, and your application
S3 Bucket: Private bucket for log storage with lifecycle management
IAM Roles:

Read-only S3 access role for verification
Write-only S3 access role for EC2 log uploads


Security: Security groups, encrypted S3 bucket, private access only

Log Management Features

System Logs: cloud-init, user-data, syslog automatically uploaded
Application Logs: Build logs, runtime logs archived to S3
Lifecycle Policy: Automatic deletion after 7 days (configurable)
