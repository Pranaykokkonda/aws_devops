# variables.tf
variable "stage" {
  description = "Deployment stage (e.g. dev, prod)"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "repo_url" {
  description = "GitHub repo URL to clone"
  type        = string
  default     = "https://github.com/techeazy-consulting/techeazy-devops.git"
}

variable "key_name" {
  description = "Name of the EC2 key pair"
  type        = string
  default     = "EC2-key"
}

variable "volume_size" {
  description = "Root volume size in GB"
  type        = number
  default     = 10
}

variable "ami_id" {
  description = "AMI ID for the instance"
  type        = string
  default     = "ami-0a7d80731ae1b2435"
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for log storage (REQUIRED)"
  type        = string
  validation {
    condition     = length(var.s3_bucket_name) > 0
    error_message = "❌ S3 bucket name is required and cannot be empty!"
  }
}

variable "log_retention_days" {
  description = "Number of days to retain logs in S3"
  type        = number
  default     = 7
}
