# Resume Analyzer & Skill Matcher

An AI-powered resume analysis and skill-matching service. Upload a PDF resume and compare it against job descriptions to get keyword matches, similarity scores, and missing skills. Built entirely on AWS using Terraform with a modular, scalable architecture and real-time analysis powered by MiniLM embeddings and FAISS.

---

## Features

- Upload PDF resumes for semantic analysis
- Match resumes to predefined job descriptions using MiniLM + FAISS
- Calculates similarity score and keyword match percentage
- Highlights missing keywords for improvement
- Logs analysis metadata to DynamoDB
- CloudWatch monitoring with SNS email alerts for “ERROR” events
- All infrastructure provisioned via Terraform

---
## Tech Stack

- **Backend**: Python 3, Flask, Sentence Transformers (MiniLM), FAISS, PyMuPDF
- **Frontend**: Static HTML/CSS (Tailwind-based) hosted on S3
- **AI/ML**: MiniLM for embeddings, FAISS for vector similarity search
- **Cloud Infra**: AWS EC2, ALB, S3, DynamoDB, CloudWatch, SNS, IAM, VPC, NAT Gateway, AWS Gaurduty, SNS.
- **IaC**: Terraform
---

## Deployment Guide

### 1. **Clone the repo**
### 2. Edit for SNS alerts.
- In line 552 of main.tf file replace your mail id in the placeholder.
### 3. Prepare Your Files
Upload the following manually to your AWS CloudShell:
- `main.tf` – your Terraform configuration file
- `resume-backend.zip` – zipped Flask backend folder
- `index.html` or frontend files – static output of your React app

### 4. Initialize and Deploy
```bash
terraform init
terraform apply
```
## 5. Access the Application

- **Frontend URL**: Shown as `frontend_s3_url` in Terraform output  
- **Backend**: Two EC2 instances behind an ALB (port 80), each running Flask on port `5000`

> Paste the frontend URL in your browser to begin.

---

## API Endpoint

### `POST /analyze` (handled by the Flask backend)

**Form Data:**
- `resume`: PDF file *(required)*
- `jobdesc`: Optional plain-text job description

**Sample Response:**
```json
{
  "similarity_score": 0.87,
  "keyword_match_percent": 76.9,
  "keywords_matched": 10,
  "missing_keywords": ["terraform", "aws", "docker"]
}
```
## Monitoring & Alerts

- **Logs**: Captured via `app.log` and `setup.log`, pushed to CloudWatch
- **Metric Filter**: Triggers if any `"ERROR"` appears in logs
- **SNS Alerts**: Email sent to your configured address for immediate issue notification
- **GuardDuty**: Active for threat detection (forwarded via EventBridge to SNS)

---

## Security & Permissions

- **IAM Role**: EC2 instances assume a custom role with scoped access to S3, DynamoDB, and CloudWatch
- **Private Subnets**: EC2s are deployed in private subnets with no public IPs
- **NAT Gateway**: Enables secure outbound internet access from private EC2s
- **Security Groups**:
  - EC2: Accepts port 5000 traffic only from ALB
  - ALB: Accepts HTTP traffic (port 80) from the internet

---

## Terraform Outputs

After successful deployment, you will see:

- `frontend_s3_url` – for accessing the app UI  
- `ec2_public_ip` (ALB DNS Name) – for backend API testing/debugging  
- DynamoDB table name – where analysis logs are stored

---

## Cost Optimization

- EC2: Two `t3.medium` instances (balanced cost and compute)
- ALB: Single ALB in front of EC2s
- S3: `force_destroy = true` used for cleanup
- CloudWatch: Log retention set to 7 days
- DynamoDB: PAY_PER_REQUEST billing mode
- NAT Gateway: Single AZ usage to reduce cost

---

## 📚 References

- [Sentence Transformers (MiniLM)](https://www.sbert.net/)
- [FAISS by Facebook](https://github.com/facebookresearch/faiss)
- [AWS CloudWatch Agent](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
