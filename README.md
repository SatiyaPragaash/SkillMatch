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

### 1. Prepare Your Files
Upload the following manually to your AWS CloudShell:
- `main.tf` – your Terraform configuration file
- `resume-backend.zip` – zipped Flask backend folder
- `index.html` or frontend files – static output of your React app

### 2. Initialize and Deploy
```bash
terraform init
terraform apply
```
## 🌐 Access the Application

- **Frontend URL**: Printed as `frontend_s3_url` in Terraform output  
- **Backend IP**: `ec2_public_ip` in Terraform output (Flask app runs on port `5000`)

---

## 🧾 API Endpoint

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
