# Resume Analyzer & Skill Matcher

An AI-powered resume analysis and skill-matching service. Upload a PDF resume and compare it against job descriptions to get keyword matches, similarity scores, and missing skills. Built on AWS using Terraform with a scalable, serverless-friendly architecture.

---

## Features

- Upload PDF resumes for automatic parsing
- Match resumes against job descriptions using MiniLM + FAISS embeddings
- Calculates similarity score and keyword match percentage
- Highlights missing keywords
- Logs metadata to DynamoDB
- Monitors errors in CloudWatch Logs
- Sends SNS email alerts for “ERROR” entries in logs

---
## Tech Stack

- **Backend**: Python 3, Flask, Sentence Transformers, FAISS, PyMuPDF
- **Frontend**: React (built output only, uploaded to S3)
- **Cloud Infra**: AWS EC2, S3, DynamoDB, SNS, CloudWatch, IAM
- **IaC**: Terraform

---

## Deployment Guide

### 1. **Clone the repo**
### 2. Edit for SNS alerts.
In line 552 of main.tf file edit the
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

- **Frontend URL**: Printed as `frontend_s3_url` in Terraform output  
- **Backend IP**: `ec2_public_ip` in Terraform output (Flask app runs on port `5000`)
- Copy the frontend url and paste it in your browser.

---

## API Endpoint

### `POST /analyze`  
Runs on the EC2 instance's public IP at port `5000`.

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

- CloudWatch Logs collect output from `app.log`  
- Metric filter detects `"ERROR"` entries  
- SNS topic sends email alerts to your mail id  

---

## Security & Permissions

- **IAM Role**: EC2 instance uses **LabRole** with access to S3, DynamoDB, and CloudWatch  
- **Security Group**: Only ports **22** (SSH) and **5000** (Flask) are open  

---

## Terraform Outputs

After running `terraform apply`, you'll get:

- `frontend_s3_url` – URL to access the frontend UI  
- `ec2_public_ip` – IP for backend testing or debugging  
- `DynamoDB table name` – stores resume analysis logs  

---

## Testing Tips

- Upload **only a resume**  
- Upload **resume + job description** (paste as plain text)  
- View:
  - Similarity score  
  - Missing keywords  
- Check logs in **DynamoDB** and **CloudWatch**

---

## Cost Optimization

- EC2 instance type: `t3.medium` (cost-efficient backend)  
- S3 buckets: `force_destroy = true` for cleanup  
- Log retention: **7 days**  
- DynamoDB billing: `PAY_PER_REQUEST` (no over-provisioning)  

---

## References

- [Sentence Transformers](https://www.sbert.net/)  
- [FAISS by Facebook](https://github.com/facebookresearch/faiss)  
- [AWS CloudWatch Agent](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Install-CloudWatch-Agent.html)  
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
