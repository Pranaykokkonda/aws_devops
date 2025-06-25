# prod_config.tfvars
stage           = "prod"
instance_type   = "t2.micro"
repo_url        = "https://github.com/Pranaykokkonda/techeazy-devops.git"
use_private_repo = true
github_username = "<Enter the GitHub userame>"
github_token    = "${{ secrets.GITHUBTOKEN }}"
key_name        = "EC2-key"
volume_size     = 20
ami_id          = "ami-0a7d80731ae1b2435"
s3_bucket_name  = "techeazy-prod-logs-bucket-20250610"
log_retention_days = 7
