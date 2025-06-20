provider "aws" {
  region = "us-east-1"
}

# -------------------------------
# 1. VPC and Subnet Setup
# -------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "resume-vpc" }
}

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = { Name = "public-subnet" }
}

resource "aws_subnet" "public_subnet_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  tags = { Name = "public-subnet-b" }
}

resource "aws_subnet" "private_backend" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "private-backend-subnet" }
}

resource "aws_subnet" "private_db" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "private-db-subnet" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "resume-igw" }
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  tags = { Name = "resume-nat-gw" }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = { Name = "private-rt" }
}

resource "aws_route_table_association" "backend_assoc" {
  subnet_id      = aws_subnet.private_backend.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_subnet_b.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_subnet" "private_backend_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = "us-east-1b"
  tags = { Name = "private-backend-subnet-b" }
}

resource "aws_route_table_association" "backend_assoc_b" {
  subnet_id      = aws_subnet.private_backend_b.id
  route_table_id = aws_route_table.private_rt.id
}

# -------------------------------
# 2. S3 Buckets
# -------------------------------
resource "random_id" "bucket_id" {
  byte_length = 4
}

resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = "resume-analyzer-frontend-${random_id.bucket_id.hex}"
  force_destroy = true
  tags = { Name = "frontend-static" }
}

resource "aws_s3_bucket_public_access_block" "frontend_bucket_block" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "frontend_public_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "PublicReadGetObject",
      Effect    = "Allow",
      Principal = "*",
      Action    = "s3:GetObject",
      Resource  = "${aws_s3_bucket.frontend_bucket.arn}/*"
    }]
  })
    depends_on = [aws_s3_bucket_public_access_block.frontend_bucket_block]
}

resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.bucket
  index_document { suffix = "index.html" }
  error_document { key = "error.html" }
}

resource "aws_s3_bucket" "resume_storage" {
  bucket        = "resume-analyzer-resumes-${random_id.bucket_id.hex}"
  force_destroy = true
  tags = { Name = "resume-storage" }
}

resource "aws_s3_object" "backend_zip" {
  bucket = aws_s3_bucket.resume_storage.id
  key    = "resume-backend.zip"
  source = "./resume-backend.zip"
  etag   = filemd5("./resume-backend.zip")
}

resource "aws_s3_object" "frontend_index" {
  bucket        = aws_s3_bucket.frontend_bucket.bucket
  key           = "index.html"
  source        = "${path.module}/index.html"
  content_type  = "text/html"
  cache_control = "no-cache"
}

resource "local_file" "config_json" {
  filename = "${path.module}/config.json"
  content  = jsonencode({
    API_BASE_URL = "http://${aws_lb.resume_alb.dns_name}"
  })
}

resource "aws_s3_object" "frontend_config" {
  bucket        = aws_s3_bucket.frontend_bucket.bucket
  key           = "config.json"
  source        = local_file.config_json.filename
  content_type  = "application/json"
  cache_control = "no-cache"
}

# -------------------------------
# 3. IAM Role and Policy for EC2
# -------------------------------
resource "aws_iam_role" "ec2_backend_role" {
  name = "resume-analyzer-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ec2_backend_policy" {
  name = "resume-analyzer-policy"
  role = aws_iam_role.ec2_backend_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "${aws_s3_bucket.resume_storage.arn}",
          "${aws_s3_bucket.resume_storage.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "cloudwatch:PutMetricData"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem"
        ],
        Resource = "${aws_dynamodb_table.logs.arn}"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "custom_instance_profile" {
  name = "resume-analyzer-instance-profile"
  role = aws_iam_role.ec2_backend_role.name
}

# -------------------------------
# 4. EC2 Security Group and Instance
# -------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "resume-analyzer-sg"
  description = "Allow backend access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5000
    to_port         = 5000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  # SSH rule (optional)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "flask_backend" {
  ami                         = "ami-0c101f26f147fa7fd"
  instance_type               = "t3.medium"
  subnet_id = aws_subnet.private_backend.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.custom_instance_profile.name

user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y unzip python3 amazon-cloudwatch-agent
              cd /home/ec2-user

              echo "Downloading backend zip..." >> setup.log
              aws s3 cp s3://${aws_s3_bucket.resume_storage.bucket}/${aws_s3_object.backend_zip.key} backend.zip >> setup.log 2>&1
              unzip backend.zip -d backend >> setup.log 2>&1
              cd backend

              echo "Upgrading pip..." >> setup.log
              python3 -m ensurepip --upgrade >> setup.log 2>&1
              python3 -m pip install --upgrade pip >> setup.log 2>&1

              echo "Installing torch CPU first..." >> setup.log
              python3 -m pip install torch==2.7.0+cpu --extra-index-url https://download.pytorch.org/whl/cpu >> setup.log 2>&1

              echo "Installing Python dependencies individually..." >> setup.log
              python3 -m pip install flask >> setup.log 2>&1
              python3 -m pip install flask-cors >> setup.log 2>&1
              python3 -m pip install boto3 >> setup.log 2>&1
              python3 -m pip install urllib3==2.4.0 >> setup.log 2>&1
              python3 -m pip install requests==2.32.3 >> setup.log 2>&1
              python3 -m pip install transformers==4.52.3 >> setup.log 2>&1
              python3 -m pip install sentence-transformers==4.1.0 >> setup.log 2>&1
              python3 -m pip install faiss-cpu==1.11.0 >> setup.log 2>&1
              python3 -m pip install numpy==2.0.2 >> setup.log 2>&1
              python3 -m pip install scipy==1.13.1 >> setup.log 2>&1
              python3 -m pip install scikit-learn==1.6.1 >> setup.log 2>&1
              python3 -m pip install nltk==3.9.1 >> setup.log 2>&1
              python3 -m pip install PyMuPDF==1.26.0 >> setup.log 2>&1
              python3 -m pip install typing_extensions==4.13.2 >> setup.log 2>&1
              python3 -m pip install filelock==3.18.0 >> setup.log 2>&1
              python3 -m pip install tqdm==4.67.1 >> setup.log 2>&1
              python3 -m pip install packaging==25.0 >> setup.log 2>&1
              python3 -m pip install huggingface-hub==0.32.2 >> setup.log 2>&1
              python3 -m pip install tokenizers==0.21.1 >> setup.log 2>&1
              python3 -m pip install Jinja2==3.1.6 >> setup.log 2>&1
              python3 -m pip install Werkzeug==3.1.3 >> setup.log 2>&1
              python3 -m pip install itsdangerous==2.2.0 >> setup.log 2>&1
              python3 -m pip install MarkupSafe==3.0.2 >> setup.log 2>&1

              echo "Starting Flask backend..." >> setup.log
              nohup python3 analyze.py > app.log 2>&1 &

              sleep 15
              echo "Uploading logs to S3..." >> setup.log
              aws s3 cp app.log s3://${aws_s3_bucket.resume_storage.bucket}/app.log >> setup.log 2>&1
              aws s3 cp setup.log s3://${aws_s3_bucket.resume_storage.bucket}/setup.log >> setup.log 2>&1

              # CloudWatch Agent config for app.log
              cat > /opt/cloudwatch-config.json <<EOL
              {
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        {
                          "file_path": "/home/ec2-user/backend/app.log",
                          "log_group_name": "/ec2/resume-analyzer",
                          "log_stream_name": "{instance_id}",
                          "timestamp_format": "%Y-%m-%d %H:%M:%S"
                        },
                        {
                          "file_path": "/home/ec2-user/setup.log",
                          "log_group_name": "/ec2/resume-analyzer",
                          "log_stream_name": "{instance_id}-setup",
                          "timestamp_format": "%Y-%m-%d %H:%M:%S"
                        }
                      ]
                    }
                  }
                }
              }
              EOL

              echo "Starting CloudWatch Agent..." >> setup.log
              /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \\
                -a fetch-config \\
                -m ec2 \\
                -c file:/opt/cloudwatch-config.json \\
                -s >> setup.log 2>&1
EOF

  tags = {
    Name = "ResumeAnalyzerEC2"
  }
}

resource "aws_instance" "flask_backend_b" {
  ami                         = "ami-0c101f26f147fa7fd"
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.private_backend_b.id
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.custom_instance_profile.name
  user_data                   = aws_instance.flask_backend.user_data

  tags = {
    Name = "ResumeAnalyzerEC2-B"
  }
}

# -------------------------------
# 6. Load Balancer
# -------------------------------

resource "aws_security_group" "alb_sg" {
  name        = "resume-alb-sg"
  description = "Allow HTTP from anywhere"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "resume_alb" {
  name               = "resume-analyzer-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [
    aws_subnet.public_subnet.id,
    aws_subnet.public_subnet_b.id
  ]
  security_groups    = [aws_security_group.alb_sg.id]
  tags = { Name = "resume-alb" }
}

resource "aws_lb_target_group" "resume_target_group" {
  name     = "resume-target-group"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }

  tags = { Name = "resume-tg" }
}

resource "aws_lb_listener" "resume_listener" {
  load_balancer_arn = aws_lb.resume_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.resume_target_group.arn
  }
}

resource "aws_lb_target_group_attachment" "resume_ec2_attachment" {
  target_group_arn = aws_lb_target_group.resume_target_group.arn
  target_id        = aws_instance.flask_backend.id
  port             = 5000
}

resource "aws_lb_target_group_attachment" "resume_ec2_attachment_b" {
  target_group_arn = aws_lb_target_group.resume_target_group.arn
  target_id        = aws_instance.flask_backend_b.id
  port             = 5000
}

# -------------------------------
# 6. DynamoDB Logging Table
# -------------------------------
resource "aws_dynamodb_table" "logs" {
  name         = "resume_logs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "timestamp"

  attribute {
    name = "timestamp"
    type = "S"
  }

  tags = {
    Name = "ResumeAnalyzerLogs"
  }
}

# -------------------------------
# 8. CloudWatch and SNS for Error Alerts
# -------------------------------
resource "aws_sns_topic" "error_alerts" {
  name = "ec2-error-alerts"
}

resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.error_alerts.arn
  protocol  = "email"
  endpoint  = "satiyapragaash23@gmail.com"
}

resource "aws_cloudwatch_log_group" "ec2_log_group" {
  name              = "/ec2/resume-analyzer"
  retention_in_days = 7
  tags = { Name = "ResumeAnalyzerEC2Logs" }
}

resource "aws_cloudwatch_log_metric_filter" "error_filter" {
  name           = "ErrorFilter"
  log_group_name = aws_cloudwatch_log_group.ec2_log_group.name
  pattern        = "ERROR"

  metric_transformation {
    name      = "EC2ErrorCount"
    namespace = "ResumeAnalyzer"
    value     = "1"
  }
}

resource "aws_cloudwatch_metric_alarm" "error_alarm" {
  alarm_name          = "ResumeAnalyzerErrorAlarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "EC2ErrorCount"
  namespace           = "ResumeAnalyzer"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggers when EC2 app.log reports errors"
  alarm_actions       = [aws_sns_topic.error_alerts.arn]
}

# -------------------------------
# 9. GuardDuty Threat Detection
# -------------------------------

resource "aws_guardduty_detector" "main" {
  enable = true
}

resource "aws_sns_topic" "guardduty_alerts" {
  name = "guardduty-alerts-topic"
}

resource "aws_sns_topic_subscription" "guardduty_email" {
  topic_arn = aws_sns_topic.guardduty_alerts.arn
  protocol  = "email"
  endpoint  = <Enter your mail id in double quotes>
}

resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "guardduty-finding-rule"
  description = "Triggers on new GuardDuty findings"
  event_pattern = jsonencode({
    source = ["aws.guardduty"],
    "detail-type" = ["GuardDuty Finding"]
  })
}

resource "aws_cloudwatch_event_target" "guardduty_to_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_findings.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.guardduty_alerts.arn
}

resource "aws_sns_topic_policy" "guardduty_topic_policy" {
  arn    = aws_sns_topic.guardduty_alerts.arn
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowEventBridgePublish",
        Effect    = "Allow",
        Principal = { Service = "events.amazonaws.com" },
        Action    = "sns:Publish",
        Resource  = aws_sns_topic.guardduty_alerts.arn
      }
    ]
  })
}

# -------------------------------
# 7. Outputs
# -------------------------------

output "frontend_s3_url" {
  value = "http://${aws_s3_bucket.frontend_bucket.bucket}.s3-website.us-east-1.amazonaws.com"
}

output "guardduty_detector_id" {
  value = aws_guardduty_detector.main.id
}

output "cloudwatch_log_group" {
  value = aws_cloudwatch_log_group.ec2_log_group.name
}