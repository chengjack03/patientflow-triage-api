# Deploy guide (AWS)

Prerequisites: an AWS account, AWS CLI configured (`aws configure`), Terraform >= 1.5, Docker.

## 1. Provision infrastructure (IaC)

```bash
cd infra
export TF_VAR_db_password='choose-a-strong-password'
export TF_VAR_anthropic_api_key='sk-ant-...'
terraform init
terraform apply        # creates ECR repo, RDS Postgres, App Runner service
```

Note the outputs: `ecr_repository_url`, `service_url`, `db_endpoint`.

## 2. Push the first image

App Runner needs an image before it can start:

```bash
ECR_URL=$(terraform output -raw ecr_repository_url)
aws ecr get-login-password | docker login --username AWS --password-stdin "${ECR_URL%/*}"
docker build -t "$ECR_URL:latest" ..
docker push "$ECR_URL:latest"
```

## 3. Wire up CI/CD

In the GitHub repo settings add these secrets:

- `AWS_REGION` - e.g. `us-east-1`
- `AWS_DEPLOY_ROLE_ARN` - an IAM role GitHub OIDC can assume with ECR push rights

After that, every push to `main` runs tests, builds the image, and pushes `:latest` to ECR.
App Runner has `auto_deployments_enabled = true`, so it redeploys automatically.

## 4. Verify

```bash
curl "$(terraform output -raw service_url)/health"
```

## Teardown

```bash
terraform destroy
```
