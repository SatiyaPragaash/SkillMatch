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
- **Frontend**: React (served from S3 static website)
- **Infrastructure**: AWS EC2, S3, DynamoDB, SNS, CloudWatch (via Terraform)

---

## Quick Start

1. **Clone the repo**
   ```bash
   git clone <your-repo-url>
   cd resume-analyzer
