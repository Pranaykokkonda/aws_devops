# Simple Java Application Deployment using Terraform🟪	 Infrastructure🛠️🌍 With S3 Log Management
This Terraform configuration deploys a Java application on AWS EC2 with comprehensive S3 log management, IAM roles, and automated log archival.

## 🏗️ Architecture Overview
## Infrastructure Components

• VPC & Networking: Custom VPC with public subnet, internet gateway, and routing

• EC2 Instance: Ubuntu instance with Java 21, Maven, and your application

• S3 Bucket: Private bucket for log storage with lifecycle management

•IAM Roles:
Read-only S3 access role for verification &
Write-only S3 access role for EC2 log uploads

• Security: Security groups, encrypted S3 bucket, private access only

## 🔧 Features

- Configurable per-environment setup (🧪 Dev / 🚀 Prod)
- VPC, Subnet, Internet Gateway, Route Table 🌐🏘️
- Security group 🛡️🔐
- Amazon EC2 instance with Java, Maven and Git 🖥️☕📦
- Auto-clones and builds Spring Boot app from GitHub with S3 bucket 🤖📥🔨
- Configurable using `.tfvars` files

---

## Log Management Features📊

• System Logs: cloud-init, user-data, syslog automatically uploaded

• Application Logs: Build logs, runtime logs archived to S3

• Lifecycle Policy: Automatic deletion after 7 days (configurable)

## 🚀 Start Deploy
• Make sure you are inside the project directory 

`chmod +x scripts/*`

`./scripts/deploy.sh dev deploy`           # or prod

• To Destroy The Infrastructure 

`./scripts/deploy.sh dev destroy` 

## 🚀 Display the output
• Application_url = "Your-application-ip"

• Instance_id = "Your-instance-id"

• Instance_profile_name = "Your-instance-profile-name"

• Instance_public_dns = "Your-public-dns"

• Instance_public_ip = "Your-public_ip"

• Readonly_role_arn = "Your-readonly_role_arn"

• Writeonly_role_arn = "Your-writeonly_role_arn"

• S3_bucket_arn = "Your-s3_bucket_arn"

• S3_bucket_name = "Your-s3_bucket_name"


## 🚀 Access the application
• Wait for 2-3 minutes for the application to start

• Access your Java application via the public IP address (e.g., http://<public_ip>) and check S3 bucket for log files

