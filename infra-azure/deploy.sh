#!/usr/bin/env bash
# Deploy the PatientFlow Triage API to Azure Container Apps.
# Prereqs: Azure CLI (`az`) logged in (`az login`), Docker not required (image is built
# in the cloud by `az acr build`). Run from the infra-azure/ directory.
set -euo pipefail

RG="${RG:-patientflow-rg}"
LOCATION="${LOCATION:-eastus}"
ACR="${ACR:-patientflowacr$RANDOM}"          # ACR names are global; must be lowercase & unique
IMAGE_TAG="${IMAGE_TAG:-latest}"

: "${ANTHROPIC_API_KEY:?Set ANTHROPIC_API_KEY}"
: "${PG_ADMIN_PASSWORD:?Set PG_ADMIN_PASSWORD (strong password)}"

echo "==> Resource group: $RG ($LOCATION)"
az group create -n "$RG" -l "$LOCATION" -o none

echo "==> Container registry: $ACR"
az acr create -n "$ACR" -g "$RG" --sku Basic --admin-enabled true -o none

echo "==> Building image in the cloud from repo Dockerfile"
# Build context is the repo root (one level up), where the Dockerfile lives.
az acr build -r "$ACR" -t "patientflow-triage-api:${IMAGE_TAG}" .. -o none

echo "==> Deploying infrastructure (Container Apps env, Postgres, Container App)"
az deployment group create \
  -g "$RG" \
  -n patientflow \
  -f main.bicep \
  -p acrName="$ACR" imageTag="$IMAGE_TAG" \
     anthropicApiKey="$ANTHROPIC_API_KEY" pgAdminPassword="$PG_ADMIN_PASSWORD" \
  -o none

API_URL=$(az deployment group show -g "$RG" -n patientflow --query properties.outputs.apiUrl.value -o tsv)
echo "==> Deployed. API URL: $API_URL"
echo "==> Health check:"
curl -fsS "$API_URL/health" && echo
echo "Interactive docs: $API_URL/docs"
