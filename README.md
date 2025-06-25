# Simple Java Application Deployment using Terraform🟪	 Infrastructure🛠️🌍 With S3 Log Management
This Terraform configuration deploys a Java application on AWS EC2 with comprehensive S3 log management, IAM roles, and automated log archival.

## 🔧 Features

- Configurable per-environment setup [🧪Dev (with public repository) and 🚀Prod (with private repository)]
- Amazon EC2 instance with Java, Maven and Git 🖥️☕📦
- Auto-clones and builds Spring Boot app from GitHub with S3 bucket 🤖📥🔨
- Configurable using `main.tf and .tfvars` files
- Create PAT token and configure in GitHub secrets with variable "GITHUBTOKEN" 
- Insert the github token variable "GITHUBTOKEN" and GitHub username for private repository at `variables.tf and prod_config.tfvars` files 

---

## 🚀 Start Deploy
• Clone the GitHub repository

`git clone -b feature/my-change https://github.com/Pranaykokkonda/aws_devops.git`

• Navigate to the aws_devops directory and make all scripts in the scripts subdirectory executable.

`cd aws_devops`

`chmod +x scripts/*`

• Run the terraform script by following command

`./scripts/deploy.sh prod deploy`

`./scripts/new.sh dev deploy`

• To Destroy The Infrastructure 

`./scripts/deploy.sh prod destroy`

`./scripts/new.sh dev destroy`

## 💻 Display the output
•Upon successful deployment the application_url, instance-id, public_ip, s3_bucket_name and s3_bucket_arn will be displayed


## 💻 Access the application
• Wait for a couple of minutes for the application to start

• Access your Java application via the public IP address (e.g., http://<public_ip>) and check S3 bucket for log files

