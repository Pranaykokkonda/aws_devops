# main.tf
provider "aws" {
  region = "us-east-1"
}

# VPC
resource "aws_vpc" "techeazy_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.vpc_name
  }
}

# Subnet
resource "aws_subnet" "techeazy_subnet" {
  vpc_id                  = aws_vpc.techeazy_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = var.subnet_name
  }
}

# Internet Gateway
resource "aws_internet_gateway" "techeazy_igw" {
  vpc_id = aws_vpc.techeazy_vpc.id

  tags = {
    Name = "${var.stage}-igw"
  }
}

# Route Table
resource "aws_route_table" "techeazy_route" {
  vpc_id = aws_vpc.techeazy_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.techeazy_igw.id
  }

  tags = {
    Name = "${var.stage}-route"
  }
}

resource "aws_route_table_association" "techeazy_assoc" {
  subnet_id      = aws_subnet.techeazy_subnet.id
  route_table_id = aws_route_table.techeazy_route.id
}

# Security Group
resource "aws_security_group" "techeazy_sg" {
  name        = var.sg_name
  description = "Allow SSH and HTTP"
  vpc_id      = aws_vpc.techeazy_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Application access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = var.sg_name
  }
}

# EC2 Instance with IAM Instance Profile
resource "aws_instance" "Java_app_deploy" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.techeazy_subnet.id
  vpc_security_group_ids      = [aws_security_group.techeazy_sg.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp2"
  }

  user_data = base64encode(templatefile("scripts/user_data.sh", {
    repo_url       = var.repo_url
    s3_bucket_name = var.s3_bucket_name
    stage          = var.stage
  }))

  tags = {
    Name = "${var.stage}-JavaAppInstance"
  }
}
