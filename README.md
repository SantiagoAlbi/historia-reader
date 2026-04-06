# Historia Reader Platform

A Netflix-style history book reading platform built as a Cloud Engineer portfolio project. Upload a PDF and it becomes immediately available to authenticated users through a secure, serverless pipeline.

---

## Architecture

![AWS Architecture](architecture.png)

```
S3 Upload → EventBridge → Step Functions → DynamoDB
                                              ↓
User → Cognito → API Gateway → Lambda → CloudFront Signed URL → PDF
```

**8 Terraform modules:**

| Module | Resources |
|--------|-----------|
| `storage` | S3 buckets (books + frontend) |
| `cdn` | CloudFront distribution, OAC, RSA key group |
| `auth` | Cognito User Pool + Client |
| `database` | DynamoDB tables (books + reading progress) |
| `api` | API Gateway HTTP, Lambda backend, Secrets Manager |
| `ingestion` | Step Functions, 4 Lambda pipeline, EventBridge |
| `observability` | CloudWatch dashboards + alarms, SNS |
| `cicd` | IAM OIDC role for GitHub Actions |

---

## Features

- **Automated ingestion pipeline** — upload a PDF to S3, EventBridge triggers Step Functions which runs validation, metadata extraction, thumbnail generation, and catalog registration automatically
- **Secure PDF delivery** — CloudFront Signed URLs with RSA key pairs; PDFs are never publicly accessible
- **JWT authentication** — Cognito issues tokens, API Gateway validates them on every request
- **Infrastructure as Code** — fully modularized Terraform with remote state in S3
- **CI/CD** — GitHub Actions with OIDC (no long-lived AWS credentials)
- **Observability** — CloudWatch dashboard tracking pipeline executions, Lambda errors and duration

---

## Ingestion Pipeline

```
PDF uploaded to S3
      ↓
EventBridge (Object Created)
      ↓
Step Functions
      ├── Validation      → checks file is valid PDF
      ├── MetadataExtractor → extracts title, author, page count
      ├── ThumbnailGenerator → generates cover image (Pillow via Klayers)
      └── CatalogRegister → writes book record to DynamoDB
```

---

## API Endpoints

All endpoints require `Authorization: Bearer <id_token>` header.

| Method | Route | Description |
|--------|-------|-------------|
| GET | `/books` | List all books (supports `?genre=` filter) |
| GET | `/books/{book_id}` | Get single book metadata |
| GET | `/books/{book_id}/url` | Get CloudFront Signed URL for PDF |
| PUT | `/books/{book_id}/progress` | Save reading progress |

---

## Tech Stack

- **IaC:** Terraform 1.x (modularized, S3 backend)
- **Cloud:** AWS (S3, CloudFront, Lambda, API Gateway HTTP, DynamoDB, Cognito, Step Functions, EventBridge, Secrets Manager, SNS, CloudWatch, IAM)
- **Runtime:** Python 3.12
- **CI/CD:** GitHub Actions + OIDC
- **Frontend:** Vanilla HTML/CSS/JS + Amazon Cognito Identity SDK

---

## Key Design Decisions

**CloudFront Signed URLs over S3 presigned URLs** — CloudFront sits in front of S3 so PDFs are never directly exposed. The Lambda signs URLs using an RSA private key stored in Secrets Manager; CloudFront validates against the public key registered in a Key Group.

**EventBridge over S3 Event Notifications** — decouples the storage layer from processing. Adding new pipeline steps requires no changes to the S3 bucket configuration.

**OIDC for CI/CD** — GitHub Actions assumes an IAM role via OIDC federation. No AWS access keys stored as GitHub secrets.

**`recovery_window_in_days = 0` on Secrets Manager** — avoids the 7-day deletion grace period when destroying and redeploying the stack.

---

## Deploy

### Prerequisites
- AWS CLI configured
- Terraform installed
- GitHub repository with Actions enabled

### First deploy

```bash
# Bootstrap remote state
cd terraform/bootstrap
terraform init && terraform apply

# Create OIDC provider (once per AWS account)
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Deploy cicd module locally (GitHub Actions needs the role to exist first)
cd ../terraform
terraform init
terraform apply -target=module.cicd

# Push to main — GitHub Actions deploys the rest
git push origin main
```

### After deploy

```bash
# Upload private key to Secrets Manager
aws secretsmanager put-secret-value \
  --secret-id historia-reader-cf-private-key-dev \
  --secret-string file:///path/to/private_key.pem

# Upload a book
aws s3 cp mybook.pdf s3://historia-reader-books-dev/books/mybook.pdf

# Get outputs
terraform output
```

### Teardown

```bash
aws s3 rm s3://historia-reader-books-dev --recursive
aws s3 rm s3://historia-reader-frontend-dev --recursive
terraform destroy
```

---

## Project Structure

```
historia-reader/
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── providers.tf
│   ├── backend.tf
│   └── modules/
│       ├── storage/
│       ├── cdn/
│       ├── auth/
│       ├── database/
│       ├── api/
│       ├── ingestion/
│       ├── observability/
│       └── cicd/
├── lambdas/
│   ├── backend/
│   ├── validation/
│   ├── metadata_extractor/
│   ├── thumbnail_generator/
│   └── catalog_register/
└── frontend/
    └── index.html
```

---

## Author

Santiago Albi — [GitHub](https://github.com/SantiagoAlbi) · [LinkedIn](https://www.linkedin.com/in/santiagoalbisetti/)
