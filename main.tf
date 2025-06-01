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

# -------------------------------
# 2. S3 Buckets
# -------------------------------
resource "random_id" "bucket_id" {
  byte_length = 4
}

# Frontend S3 Bucket
resource "aws_s3_bucket" "frontend_bucket" {
  bucket        = "resume-analyzer-frontend-${random_id.bucket_id.hex}"
  force_destroy = true
  tags = { Name = "frontend-static" }
}

# Configure S3 Website Hosting
resource "aws_s3_bucket_website_configuration" "frontend_website" {
  bucket = aws_s3_bucket.frontend_bucket.bucket

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Backend Resume Storage Bucket
resource "aws_s3_bucket" "resume_storage" {
  bucket        = "resume-analyzer-resumes-${random_id.bucket_id.hex}"
  force_destroy = true
  tags = { Name = "resume-storage" }
}

# Upload backend zip to S3
resource "aws_s3_object" "backend_zip" {
  bucket = aws_s3_bucket.resume_storage.id
  key    = "resume-backend.zip"
  source = "./resume-backend.zip"
  etag   = filemd5("./resume-backend.zip")
}

# -------------------------------
# 3. IAM Instance Profile (LabRole)
# -------------------------------
data "aws_iam_role" "labrole" {
  name = "LabRole"
}

resource "aws_iam_instance_profile" "lab_instance_profile" {
  name = "lab-instance-profile"
  role = data.aws_iam_role.labrole.name
}


# -------------------------------
# 4. EC2 Security Group
# -------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "resume-analyzer-sg"
  description = "Allow backend access"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Open to the world
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------------
# 5. EC2 Backend Instance
# -------------------------------
resource "aws_instance" "flask_backend" {
  ami                         = "ami-0c101f26f147fa7fd" # Amazon Linux 2023
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.lab_instance_profile.name

user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y unzip python3
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
EOF

  tags = {
    Name = "ResumeAnalyzerEC2"
  }
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
# 7. Outputs
# -------------------------------
output "frontend_s3_url" {
  value = "http://${aws_s3_bucket.frontend_bucket.bucket}.s3-website.us-east-1.amazonaws.com"
}

output "ec2_private_ip" {
  value = aws_instance.flask_backend.private_ip
}

output "ec2_public_ip" {
  value = aws_instance.flask_backend.public_ip
}