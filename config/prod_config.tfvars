# prod_config.tfvars
stage           = "prod"
instance_type   = "t2.micro"
repo_url        = "https://github.com/techeazy-consulting/techeazy-devops.git"
key_name        = "EC2-key"
volume_size     = 20
vpc_name        = "techeazy-prod-vpc"
subnet_name     = "techeazy-prod-subnet"
sg_name         = "techeazy-prod-sg"
ami_id          = "ami-0a7d80731ae1b2435"
s3_bucket_name  = "techeazy-prod-logs-bucket-20250610"
log_retention_days = 7
