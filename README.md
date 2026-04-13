# Infrastructure as Code — Terraform + GitHub Actions + AWS

![Terraform](https://img.shields.io/badge/Terraform-1.7.0-7B42BC?logo=terraform)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?logo=githubactions)
![AWS](https://img.shields.io/badge/AWS-Free_Tier-FF9900?logo=amazonaws)
![Auth](https://img.shields.io/badge/Auth-OIDC-green)

A production-style Infrastructure as Code project that provisions AWS resources automatically using Terraform and GitHub Actions — with OIDC authentication (no static AWS keys stored anywhere).

Built as a learning project to demonstrate real DevOps workflows used at startups and scale-ups.

---

## What this project does

Every time code is pushed or a pull request is opened, GitHub Actions runs Terraform automatically:

| Event | Pipeline job | What happens |
|---|---|---|
| Push to `feature/*` or `fix/*` | `terraform-validate` | Validates syntax + runs plan so the dev sees impact |
| Open a pull request to `main` | `terraform-plan` | Posts the full plan output as a PR comment for team review |
| Merge to `main` | `terraform-apply` | Creates or updates real AWS infrastructure |
| Manual trigger | `terraform-manual` | Apply or destroy on demand |

---

## Architecture

```
Developer
    │
    ├── push feature/xyz ──► GitHub Actions: validate + plan
    │
    ├── open PR ──────────► GitHub Actions: plan (posts comment on PR)
    │                              │
    │                        Team reviews plan
    │                              │
    └── merge to main ────► GitHub Actions: apply
                                   │
                             OIDC auth (no static keys)
                                   │
                              AWS IAM role
                                   │
                    ┌──────────────┼──────────────┐
                    │              │               │
                  EC2           S3 bucket        VPC
                t2.micro      (versioned)    + subnet + SG
                    │
              State stored in
              S3 + DynamoDB lock
```

---

## AWS resources provisioned

| Resource | Details | Purpose |
|---|---|---|
| VPC | `10.0.0.0/16` | Isolated private network |
| Subnet | `10.0.1.0/24` in `ap-south-1a` | Public subnet for EC2 |
| Internet Gateway | Attached to VPC | Allows internet traffic |
| Route Table | `0.0.0.0/0` → IGW | Routes traffic to internet |
| Security Group | Port 22 (SSH), 80 (HTTP) open | Firewall around EC2 |
| EC2 instance | `t2.micro`, Amazon Linux 2 | Virtual server (free tier) |
| S3 app bucket | Versioning enabled | Application file storage |
| S3 state bucket | Versioning + encryption | Terraform remote state |
| DynamoDB table | `LockID` partition key | State locking |
| IAM OIDC role | Trust policy for GitHub Actions | Secure authentication |

---

## Authentication — OIDC (no static keys)

This project uses OpenID Connect (OIDC) instead of storing AWS access keys as GitHub secrets.

**How it works:**
1. GitHub Actions requests a short-lived OIDC token from GitHub
2. AWS IAM verifies the token against the trusted GitHub OIDC provider
3. AWS issues temporary credentials scoped to the IAM role
4. Credentials expire automatically when the job finishes

**Why this is better than static keys:**
- No long-lived credentials stored anywhere
- No key rotation needed
- If a token is somehow intercepted, it is already expired
- Every job session is traceable in AWS CloudTrail

---

## Project structure

```
iac-terraform-aws/
├── .github/
│   └── workflows/
│       └── terraform.yml      # GitHub Actions pipeline
├── terraform/
│   ├── backend.tf             # Remote state config (S3 + DynamoDB)
│   ├── provider.tf            # AWS provider declaration
│   ├── variables.tf           # All input variables with defaults
│   ├── main.tf                # AWS resources (EC2, S3, VPC, SG)
│   └── outputs.tf             # Values printed after apply
├── .gitignore                 # Excludes .terraform/, state files, tfvars
└── README.md
```

---

## Prerequisites

- AWS account (free tier works)
- GitHub account
- Terraform CLI >= 1.5.0
- AWS CLI v2

---

## Setup — one time only

### 1. Create the state backend manually

The S3 bucket and DynamoDB table that store Terraform state cannot be created by Terraform itself. Create them once:

```bash
# Create S3 state bucket
aws s3api create-bucket \
  --bucket tf-state-iac-yourname \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket tf-state-iac-yourname \
  --versioning-configuration Status=Enabled

# Enable encryption
aws s3api put-bucket-encryption \
  --bucket tf-state-iac-yourname \
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'

# Create DynamoDB lock table
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1
```

### 2. Set up OIDC in AWS

In AWS IAM, create an identity provider:
- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

Create an IAM role named `Github_OIDC` with this trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/iac-terraform-aws:*"
        }
      }
    }
  ]
}
```

### 3. Update backend.tf

Replace `tf-state-iac-ayan` with your actual bucket name in `terraform/backend.tf`.

### 4. Test locally

```bash
cd terraform/
terraform init
terraform validate
terraform plan
```

---

## How to use the pipeline

### Developing a change

```bash
git checkout -b feature/my-change
# make changes to .tf files
git add .
git commit -m "feat: describe your change"
git push origin feature/my-change
# go to GitHub Actions tab to see validate + plan results
```

### Deploying to production

```bash
# open a pull request from your feature branch to main
# review the plan comment posted automatically
# get approval from a team member
# merge — apply runs automatically
```

### Destroying infrastructure

Go to GitHub → Actions → Terraform CI/CD → Run workflow → select `destroy`

Or locally (for development only):

```bash
cd terraform/
terraform destroy
```

---

## Key concepts learned in this project

| Concept | What it means | Where it appears |
|---|---|---|
| Infrastructure as Code | Describe infra in files, not clicks | All `.tf` files |
| Remote state | Store state in S3, not on laptop | `backend.tf` |
| State locking | Prevent concurrent applies | DynamoDB table |
| OIDC auth | Temporary credentials, no static keys | GitHub Actions |
| GitOps | Git is the source of truth for infra | PR workflow |
| Least privilege | IAM role only has permissions it needs | `Github_OIDC` role |
| Branch protection | PRs required, plan must pass before merge | GitHub settings |

---

## Cost

This project runs entirely within AWS Free Tier:

| Resource | Free tier allowance | This project uses |
|---|---|---|
| EC2 t2.micro | 750 hrs/month (12 months) | 1 instance, destroy when done |
| S3 | 5 GB, 20k GET, 2k PUT (12 months) | KB of data |
| DynamoDB | 25 GB + 25 WCU (forever) | ~10 requests total |

Always run `terraform destroy` when done testing.

---

## Learning resources

### Terraform
- [Official Terraform docs](https://developer.hashicorp.com/terraform/docs)
- [Terraform AWS provider docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform best practices](https://developer.hashicorp.com/terraform/tutorials)

### GitHub Actions
- [GitHub Actions docs](https://docs.github.com/en/actions)
- [Workflow syntax reference](https://docs.github.com/en/actions/writing-workflows/workflow-syntax-for-github-actions)
- [OIDC with AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

### AWS
- [AWS VPC concepts](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
- [EC2 free tier](https://aws.amazon.com/free/)
- [IAM best practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)

---

## Author

Built by Ayan as a DevOps learning project.
Demonstrates: Terraform · GitHub Actions · AWS · OIDC · GitOps · IaC
