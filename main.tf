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
    stage          = var.stage,
    cw_agent_config_url = var.cw_agent_config_url
  }))

  tags = {
    Name = "${var.stage}-JavaAppInstance"
  }
}

variable "cw_agent_config_url" {
  type = string
}

resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/ec2/app"
  retention_in_days = 7
}

resource "aws_sns_topic" "app_alerts" {
  name = "app-alerts-topic"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.app_alerts.arn
  protocol  = "email"
  endpoint  = "Enter-your-@gmail.com"
}

resource "aws_cloudwatch_log_metric_filter" "error_filter" {
  name           = "error-filter"
  log_group_name = aws_cloudwatch_log_group.app_logs.name
  pattern        = "?ERROR ?Exception"

  metric_transformation {
    name      = "AppErrorCount"
    namespace = "AppLogs"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "error_alarm" {
  alarm_name          = "AppErrorAlarm"
  metric_name         = "AppErrorCount"
  namespace           = "AppMonitoring"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  alarm_description   = "Triggers when log contains 'ERROR' or 'Exception'"
  alarm_actions       = [aws_sns_topic.app_alerts.arn]
  treat_missing_data  = "notBreaching"
  depends_on          = [aws_cloudwatch_log_metric_filter.error_filter]
}

