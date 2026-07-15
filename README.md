# PatientFlow Triage API

A production-oriented, LLM-powered patient-intake triage service. It accepts free-text
symptom descriptions, uses the Anthropic Claude API to classify urgency and route the
patient, persists each record to PostgreSQL, and exposes a clean REST API. Built to be
containerized, deployed to AWS via Terraform, and shipped through a GitHub Actions CI/CD
pipeline.

> Not a medical device. This is a demonstration of AI + healthcare infrastructure patterns
> (structured LLM output, low-latency APIs, IaC, CI/CD), not a clinical decision tool.

## Architecture

```
Client --HTTP--> FastAPI (app/)                     +- Anthropic Claude API (structured JSON triage)
                   |  POST /intake  -- llm.triage() -+
                   |  GET  /intake/{id}
                   |  GET  /health   (load-balancer probe)
                   +-- SQLAlchemy ORM --> PostgreSQL (RDS in prod, SQLite locally)
```

- **API layer** - FastAPI, async-ready, auto-generated OpenAPI docs at `/docs`.
- **LLM layer** - `app/llm.py` sends symptoms to Claude and parses a strict JSON object
  (`urgency_level`, `recommended_department`, `summary`). A stub mode returns deterministic
  results so tests and CI run with no keys or network.
- **Data layer** - SQLAlchemy ORM (`app/models.py`) over PostgreSQL; SQLite is the zero-setup
  local default.
- **Infra** - Docker image, Terraform-provisioned ECR + RDS + App Runner, GitHub Actions CI/CD.

## Tech stack

| Layer        | Tech |
|--------------|------|
| Language     | Python 3.12 |
| API          | FastAPI, Uvicorn |
| Data         | PostgreSQL, SQLAlchemy ORM, Pydantic |
| LLM          | Anthropic Claude API (structured output) |
| Container    | Docker, docker-compose |
| IaC          | Terraform (AWS: ECR, RDS, App Runner) |
| CI/CD        | GitHub Actions |

## API

| Method | Path            | Description |
|--------|-----------------|-------------|
| GET    | `/health`       | Liveness/readiness probe |
| POST   | `/intake`       | Submit symptoms -> AI triage result (persisted) |
| GET    | `/intake/{id}`  | Fetch a stored intake record |

Example:

```bash
curl -X POST localhost:8000/intake \
  -H 'content-type: application/json' \
  -d '{"patient_reference":"patient-001","reported_symptoms":"Chest tightness for 2 hours"}'
```

```json
{
  "urgency_level": "emergency",
  "recommended_department": "Emergency Department",
  "summary": "High-risk symptoms reported; immediate evaluation recommended.",
  "id": 1,
  "patient_reference": "patient-001",
  "created_at": "2026-07-15T12:00:00Z"
}
```

## Run locally

Zero-setup (SQLite + stubbed LLM):

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
LLM_STUB_MODE=true uvicorn app.main:app --reload
# open http://localhost:8000/docs
```

With Docker + Postgres:

```bash
docker compose up --build
```

With live Claude triage: copy `.env.example` to `.env`, set `ANTHROPIC_API_KEY`, and set
`LLM_STUB_MODE=false`.

## Test

```bash
LLM_STUB_MODE=true pytest -q
```

## Deploy to AWS (Terraform + CI/CD)

See [`infra/DEPLOY.md`](infra/DEPLOY.md) for the full walkthrough. In short:

1. `cd infra && terraform init && terraform apply` - provisions ECR, RDS Postgres, and an
   App Runner service (infrastructure as code).
2. Add repo secrets `AWS_REGION` and `AWS_DEPLOY_ROLE_ARN`.
3. Push to `main` - GitHub Actions runs lint + tests, builds the Docker image, and pushes it
   to ECR; App Runner auto-deploys the new image.
