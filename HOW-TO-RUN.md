# BankApp — GitHub Actions Training Lab
## How to Run (Zero Cloud Cost)

---

## Prerequisites — install these once

```bash
# 1. Docker Desktop (or Docker Engine on Linux)
#    https://docs.docker.com/get-docker/

# 2. act — runs GitHub Actions locally (no GitHub needed for practice)
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
act --version   # should print act version 0.2.x

# 3. Git (you already have this)
git --version
```

---

## Step 1 — Set up the project

```bash
# Clone or copy this folder
cd bankapp

# Initialize as a git repo (required for act + GitHub Actions)
git init
git add .
git commit -m "initial: banking app"

# Create the branch the pipeline expects
git checkout -b main
```

---

## Step 2 — Run the app locally (verify it works first)

```bash
# Start Postgres + app together
docker compose up --build

# In another terminal — test the API
# Create an account
curl -X POST http://localhost:8080/api/v1/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "ownerName": "Rohan Dev",
    "email": "rohan@bank.com",
    "balance": 10000,
    "type": "SAVINGS"
  }'

# Note the accountNumber from the response, e.g. ACC1A2B3C4D5E

# Deposit money
curl -X POST http://localhost:8080/api/v1/accounts/ACC1A2B3C4D5E/deposit \
  -H "Content-Type: application/json" \
  -d '{"amount": 500}'

# Check health
curl http://localhost:8080/actuator/health

# Stop everything
docker compose down
```

---

## Step 3 — Run GitHub Actions locally with act

```bash
# Create a .secrets file for act (never commit this)
cat > .secrets << 'EOF'
DOCKERHUB_USERNAME=your-dockerhub-username
DOCKERHUB_TOKEN=your-dockerhub-token
EOF

# Run only the test job (fastest feedback loop)
act push -j test --secret-file .secrets

# Run the full pipeline
act push --secret-file .secrets

# Simulate a pull_request event
act pull_request --secret-file .secrets

# Run with verbose output to see every step
act push -j test --secret-file .secrets -v

# Run a specific workflow file
act push -W .github/workflows/ci-cd.yml --secret-file .secrets

# Simulate workflow_dispatch (manual trigger)
act workflow_dispatch --secret-file .secrets \
  -e '{"inputs":{"environment":"staging","skip_tests":"false"}}'
```

> **First run note:** act downloads a Docker image to simulate the GitHub runner.
> Choose "Medium" when prompted (~500MB, has most tools pre-installed).

---

## Step 4 — Run just the Maven tests directly

```bash
# Without Docker (uses H2 in-memory DB for tests)
./mvnw test -Dspring.profiles.active=test

# With coverage report
./mvnw verify -Dspring.profiles.active=test

# View coverage report
open target/site/jacoco/index.html
```

---

## Step 5 — Push to GitHub and run the real pipeline

```bash
# Create a repo at github.com/your-username/bankapp
git remote add origin https://github.com/YOUR_USERNAME/bankapp.git

# Add secrets in GitHub:
# Repo → Settings → Secrets and variables → Actions → New secret
#   DOCKERHUB_USERNAME = your Docker Hub username
#   DOCKERHUB_TOKEN    = your Docker Hub access token (not password!)

# Add GitHub Environments:
# Repo → Settings → Environments → New environment
#   - Create "staging"  (no protection rules)
#   - Create "production" (enable "Required reviewers" → add yourself)

# Push to trigger the pipeline
git push -u origin main
```

---

## Bug Hunting Exercises

The pipeline has **5 intentional bugs** — the same bugs that appear in real production pipelines.

### BUG-1: Wrong branch filter (Line 58 in ci-cd.yml)
**Symptom:** You push to `main` but the pipeline never triggers.
**Hint:** Look at the `on.push.branches` list.
**Fix:** Add `main` to the branches list.

### BUG-2: Stale Maven cache key (Line 117)
**Symptom:** You add a new dependency to pom.xml. Old cache gets restored.
Build fails with "artifact not found" or uses wrong version.
**Hint:** Cache keys should include a hash of the file that defines dependencies.
**Fix:**
```yaml
key: ${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}
```

### BUG-3: `latest` tag on every PR build (Line 152)
**Symptom:** Your stable production `latest` image gets overwritten every time
someone opens a PR — even before code review.
**Hint:** `latest` should only be pushed from the main branch.
**Fix:**
```yaml
type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}
```

### BUG-4: Trivy doesn't block on CRITICAL vulns (Line 196)
**Symptom:** A CRITICAL CVE slips through into production because Trivy
only looks for HIGH severity and exit-code is 0 (never fails).
**Hint:** Two things to fix — severity list AND exit-code.
**Fix:**
```yaml
severity: "CRITICAL,HIGH"
exit-code: "1"
```

### BUG-5: Production deploys without staging gate (Line 243)
**Symptom:** Production can deploy even if staging deployment failed.
The `needs` field is wrong — production doesn't wait for staging.
**Hint:** A job's `needs` field controls its dependency chain.
**Fix:**
```yaml
needs: [build-image, deploy-staging]
```

---

## Advanced Concepts Practiced

| Concept | Where |
|---|---|
| Concurrency groups + cancel-in-progress | Top of ci-cd.yml |
| Matrix strategy (multi-JDK) | `test` job |
| Artifact passing between jobs | `upload-artifact` / `download-artifact` |
| Reusable workflows (`workflow_call`) | reusable-health-check.yml |
| GitHub Environments + approval gates | `deploy-staging`, `deploy-production` |
| OIDC least-privilege permissions | `security-scan` job |
| Docker layer caching in CI (`type=gha`) | `build-image` job |
| SBOM + provenance attestation (SLSA) | `build-image` job |
| SARIF upload to GitHub Security tab | `security-scan` job |
| Scheduled workflows + auto issue creation | nightly-audit.yml |
| GitHub Script for PR comments | `deploy-staging` job |
| Blue-Green deployment strategy | `deploy-production` job |
| Conditional execution (`if` expressions) | Multiple jobs |
| Job outputs used by downstream jobs | `build-image` → `deploy-staging` |
| Pipeline-wide notifications (`if: always()`) | `notify` job |

---

## Directory Structure

```
bankapp/
├── .github/
│   ├── workflows/
│   │   ├── ci-cd.yml                    ← main pipeline (5 bugs inside)
│   │   ├── reusable-health-check.yml    ← reusable workflow
│   │   └── nightly-audit.yml           ← scheduled security audit
│   └── owasp-suppressions.xml
├── src/
│   ├── main/java/com/bank/
│   │   ├── BankApplication.java
│   │   ├── controller/AccountController.java
│   │   ├── service/AccountService.java
│   │   ├── model/{Account,Transaction}.java
│   │   ├── repository/{Account,Transaction}Repository.java
│   │   ├── exception/
│   │   └── config/SecurityConfig.java
│   └── test/java/com/bank/
│       ├── AccountServiceTest.java       ← unit tests
│       └── AccountControllerIntegrationTest.java
├── Dockerfile                           ← multi-stage, non-root user
├── docker-compose.yml                   ← local dev environment
├── pom.xml
└── HOW-TO-RUN.md
```
