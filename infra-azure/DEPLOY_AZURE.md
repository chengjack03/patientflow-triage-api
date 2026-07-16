# Deploy to Azure Container Apps

Deploys the PatientFlow Triage API as a container on Azure Container Apps, backed by an
Azure PostgreSQL Flexible Server, with infrastructure defined as code in Bicep.

## Prerequisites

- An Azure subscription
- Azure CLI installed and logged in: `az login`
- The Container Apps extension (installed automatically on first use, or `az extension add --name containerapp`)

No local Docker needed: `az acr build` builds the image in the cloud from the repo Dockerfile.

## One-command deploy

From the `infra-azure/` directory:

```bash
export ANTHROPIC_API_KEY='sk-ant-...'
export PG_ADMIN_PASSWORD='a-strong-password'
./deploy.sh
```

The script:

1. Creates a resource group.
2. Creates an Azure Container Registry and builds/pushes the image with `az acr build`.
3. Deploys `main.bicep`: Log Analytics, a Container Apps environment, PostgreSQL Flexible
   Server + database + firewall rule, and the Container App (external ingress on port 8000,
   secrets for the Anthropic key and DB URL, health probe on `/health`, autoscale 1–3 replicas).
4. Prints the public HTTPS URL and runs a health check.

## What maps to what (AWS → Azure)

| Concern            | AWS (infra/)        | Azure (infra-azure/)          |
|--------------------|---------------------|-------------------------------|
| Image registry     | ECR                 | Azure Container Registry      |
| Container runtime  | App Runner          | Azure Container Apps          |
| Managed Postgres   | RDS                 | PostgreSQL Flexible Server    |
| IaC                | Terraform           | Bicep                         |
| Secrets/config     | env at deploy       | Container App secrets         |

## Teardown

```bash
az group delete -n patientflow-rg --yes --no-wait
```
