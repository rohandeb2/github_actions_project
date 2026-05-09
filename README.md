# 🏦 BankApp — Production-Grade Banking REST API

> A fully containerized Spring Boot banking application with an enterprise-grade CI/CD pipeline, multi-layer security scanning, blue-green deployments, and automated rollback.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [CI/CD Pipeline](#cicd-pipeline)
- [Security Scanning](#security-scanning)
- [Infrastructure (Terraform)](#infrastructure-terraform)
- [Getting Started](#getting-started)
- [API Reference](#api-reference)
- [Environment Variables & Secrets](#environment-variables--secrets)
- [Project Structure](#project-structure)

---

## Overview

BankApp is a production-ready REST API for core banking operations — account creation, deposits, and fund transfers. It is built with **Spring Boot 3.2**, backed by **PostgreSQL**, and deployed on **AWS EKS** via a fully automated GitHub Actions pipeline.

Every push to `main` runs a 6-stage pipeline covering code quality, 6 parallel security scans, Docker image build, staging deployment, production blue-green deployment, and automatic rollback on failure.

---

## Architecture

```
Internet
    │
    ▼
[ ALB / Ingress ]
    │
    ▼
[ EKS — Spring Boot Pods ]
    │              │
    ▼              ▼
[ RDS PostgreSQL ] [ ElastiCache (optional) ]
  Multi-AZ         Session Store
  Private Subnet   Private Subnet
```

**Key design decisions:**

- EC2 nodes and RDS run in **private subnets only** — no public database exposure
- One **NAT Gateway per AZ** for high-availability outbound traffic
- EKS secrets encrypted at rest with a **customer-managed KMS key**
- IMDSv2 enforced on all worker nodes (prevents SSRF-based credential theft)
- RDS has **deletion protection** and **7-day automated backups** enabled

---

## Tech Stack

| Layer | Technology |
|---|---|
| Application | Java 21, Spring Boot 3.2, Spring Security, Spring Data JPA |
| Database | PostgreSQL 16 (RDS Multi-AZ) |
| Container | Docker (multi-stage, distroless runtime) |
| Orchestration | AWS EKS (Kubernetes 1.29) |
| Infrastructure | Terraform 1.6+, AWS VPC / EKS / RDS |
| CI/CD | GitHub Actions |
| Security Scanning | Semgrep, SonarQube, Trivy, OWASP, TFLint, Checkov |
| Monitoring | Spring Actuator, Prometheus (Micrometer), CloudWatch |
| API Docs | SpringDoc OpenAPI / Swagger UI |

---

## CI/CD Pipeline

Every push to `main` runs all 6 stages in sequence. Pull requests run stages 1 and 2 only.

```
Push to main
     │
     ▼
┌─────────────────────────────────┐
│  Stage 1 — Code Quality         │
│  Unit tests · Integration tests │
│  JaCoCo coverage gate (≥ 70%)   │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│  Stage 2 — Security Scanning    │  ← 6 scanners run in parallel
│  Semgrep · SonarQube · Trivy    │
│  OWASP · TFLint · Checkov       │
└────────────────┬────────────────┘
                 │  (Security Gate must pass)
                 ▼
┌─────────────────────────────────┐
│  Stage 3 — Docker Build & Push  │
│  Multi-stage build · SBOM       │
│  Image signed · Trivy image scan│
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│  Stage 4 — Deploy Staging       │
│  Docker Compose deploy          │
│  Smoke test (actuator/health)   │
└────────────────┬────────────────┘
                 │
                 ▼
┌─────────────────────────────────┐
│  Stage 5 — Deploy Production    │  ← Manual approval gate
│  Blue-Green deploy              │
│  Production smoke test          │
│  Update LAST_STABLE_SHA         │
└────────────────┬────────────────┘
                 │  (on failure)
                 ▼
┌─────────────────────────────────┐
│  Stage 6 — Auto Rollback        │
│  Restore last stable image      │
│  Rollback smoke test            │
└─────────────────────────────────┘
                 │
                 ▼
       📧 Email notification
       sent to both recipients
       on every outcome
```

### Rollback Strategy

- Before each production deploy, the current stable SHA is saved as `LAST_STABLE_SHA`
- If staging or production smoke tests fail, Stage 6 auto-triggers and redeploys the last stable image
- A **manual force-rollback** can also be triggered at any time via `workflow_dispatch`

---

## Security Scanning

All 6 scanners run in parallel after tests pass. The **Security Gate** blocks the build if any scanner reports a failure.

| Scanner | What It Checks |
|---|---|
| **Semgrep** | Java SAST — OWASP Top 10, SQL injection, secrets in code |
| **SonarQube** | Code quality gate, test coverage, code smells, security hotspots |
| **Trivy** | Filesystem and Docker image CVE scanning (CRITICAL / HIGH) |
| **OWASP Dependency Check** | Known CVEs in Maven dependencies (CVSS ≥ 7 fails build) |
| **TFLint** | Terraform linting — naming conventions, deprecated syntax |
| **Checkov** | Terraform and Dockerfile IaC policy checks |

All scanner results are uploaded as SARIF and appear in the **GitHub Security → Code Scanning** tab.

---

## Infrastructure (Terraform)

Infrastructure is defined as code under `terraform/` and organized into reusable modules.

```
terraform/
├── main.tf               # Root module — wires VPC, EKS, RDS, SGs
├── variables.tf          # All input variables with descriptions
├── versions.tf           # Provider versions + S3 backend config
├── environments/
│   └── prod/
│       └── terraform.tfvars
└── modules/
    ├── vpc/              # VPC, subnets, NAT gateways, flow logs
    ├── eks/              # EKS cluster, node group, KMS, add-ons
    ├── rds/              # RDS PostgreSQL, parameter group, monitoring
    └── security-groups/  # EKS and RDS security groups
```

**To deploy infrastructure:**

```bash
cd terraform
export TF_VAR_db_username=<username>
export TF_VAR_db_password=<password>

terraform init
terraform plan -var-file=environments/prod/terraform.tfvars
terraform apply -var-file=environments/prod/terraform.tfvars
```

> ⚠️ DB credentials are never stored in `.tfvars` files. Always pass them via `TF_VAR_*` environment variables or AWS Secrets Manager.

---

## Getting Started

### Prerequisites

- Docker & Docker Compose
- Java 21 (for local development)
- Maven 3.9+

### Run Locally

```bash
# Clone the repository
git clone https://github.com/<your-org>/bankapp.git
cd bankapp

# Start the app + PostgreSQL + pgAdmin
docker compose up -d

# App:      http://localhost:8080
# Swagger:  http://localhost:8080/swagger-ui.html
# Actuator: http://localhost:8080/actuator/health
# pgAdmin:  http://localhost:5050  (admin@bank.com / admin)
```

### Run Tests

```bash
# Run all tests with coverage report
mvn verify -Dspring.profiles.active=test

# Coverage report generated at:
# target/site/jacoco/index.html
```

### Run SonarQube Locally

```bash
# Start SonarQube
docker compose -f docker-compose.sonar.yml up -d
# Access: http://localhost:9000  (admin / admin)

# Run analysis
mvn sonar:sonar \
  -Dsonar.host.url=http://localhost:9000 \
  -Dsonar.token=<your-local-token>
```

---

## API Reference

Base URL: `http://localhost:8080/api/v1`

Full interactive docs available at `/swagger-ui.html`.

| Method | Endpoint | Description |
|---|---|---|
| `POST` | `/accounts` | Create a new bank account |
| `GET` | `/accounts` | List all accounts |
| `GET` | `/accounts/{accountNumber}` | Get account by number |
| `POST` | `/accounts/{accountNumber}/deposit` | Deposit funds |
| `POST` | `/accounts/transfer` | Transfer funds between accounts |
| `GET` | `/accounts/{accountNumber}/transactions` | Get transaction history |
| `GET` | `/accounts/health` | Service health check |

**Example — Create Account:**

```bash
curl -X POST http://localhost:8080/api/v1/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "ownerName": "John Doe",
    "email": "john@example.com",
    "type": "SAVINGS",
    "balance": 1000.00
  }'
```

**Example — Transfer Funds:**

```bash
curl -X POST http://localhost:8080/api/v1/accounts/transfer \
  -H "Content-Type: application/json" \
  -d '{
    "fromAccountNumber": "ACC1234567890",
    "toAccountNumber": "ACC0987654321",
    "amount": "500.00",
    "description": "Rent payment"
  }'
```

---

## Environment Variables & Secrets

### GitHub Secrets (Settings → Secrets → Actions)

| Secret | Description |
|---|---|
| `DOCKERHUB_USERNAME` | Docker Hub username |
| `DOCKERHUB_TOKEN` | Docker Hub access token |
| `SONAR_TOKEN` | SonarCloud user token |
| `NVD_API_KEY` | NVD API key (speeds up OWASP scans) |
| `SEMGREP_APP_TOKEN` | Semgrep token (optional) |
| `MAIL_USERNAME` | Gmail address used to send pipeline notifications |
| `MAIL_PASSWORD` | Gmail App Password |
| `GH_PAT` | GitHub PAT (repo scope) — updates `LAST_STABLE_SHA` |

### GitHub Variables (Settings → Secrets → Variables)

| Variable | Description |
|---|---|
| `SONAR_HOST_URL` | SonarQube server URL |
| `LAST_STABLE_SHA` | Auto-managed by pipeline — seed with any valid commit SHA |

### Application Environment Variables

| Variable | Default | Description |
|---|---|---|
| `DB_HOST` | `localhost` | PostgreSQL host |
| `DB_PORT` | `5432` | PostgreSQL port |
| `DB_NAME` | `bankdb` | Database name |
| `DB_USER` | `bankuser` | Database username |
| `DB_PASSWORD` | `bankpass` | Database password |
| `SERVER_PORT` | `8080` | Application port |
| `APP_ENV` | `local` | Environment label |

---

## Project Structure

```
bankapp/
├── .github/
│   └── workflows/
│       └── ci-cd.yaml          # Full 6-stage pipeline
├── src/
│   ├── main/java/com/bank/
│   │   ├── BankApplication.java
│   │   ├── config/             # Security & OpenAPI config
│   │   ├── controller/         # REST controllers
│   │   ├── model/              # JPA entities (Account, Transaction)
│   │   ├── repository/         # Spring Data repositories
│   │   ├── service/            # Business logic
│   │   └── exception/          # Global exception handling
│   └── test/java/com/bank/
│       ├── AccountServiceTest.java          # Unit tests (Mockito)
│       └── AccountControllerIntegrationTest.java  # Integration tests
├── terraform/                  # AWS infrastructure as code
│   ├── modules/
│   │   ├── vpc/
│   │   ├── eks/
│   │   ├── rds/
│   │   └── security-groups/
│   └── environments/prod/
├── Dockerfile                  # Multi-stage build (deps → builder → runtime)
├── docker-compose.yml          # Local dev stack
├── docker-compose.sonar.yml    # Local SonarQube stack
└── pom.xml                     # Maven dependencies
```

---

## 📧 Notifications

The pipeline sends an HTML email report on every run — success, failure, or rollback — to the configured recipients. Reports include per-stage results, the deployed image SHA, and a direct link to the pipeline run.

---

## 📄 License

This project is for DevOps training and demonstration purposes.
