# ---------------------------------------------------------------------------
# Container registry for the API image (pushed by the GitHub Actions pipeline).
# ---------------------------------------------------------------------------
resource "aws_ecr_repository" "api" {
  name                 = var.project_name
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# ---------------------------------------------------------------------------
# Managed PostgreSQL (RDS). Small instance sized for an early-stage service.
# ---------------------------------------------------------------------------
resource "aws_db_instance" "postgres" {
  identifier             = "${var.project_name}-db"
  engine                 = "postgres"
  engine_version         = "16"
  instance_class         = "db.t4g.micro"
  allocated_storage      = 20
  db_name                = "patientflow"
  username               = var.db_username
  password               = var.db_password
  skip_final_snapshot    = true
  publicly_accessible    = false
  storage_encrypted      = true
  apply_immediately      = true
}

# ---------------------------------------------------------------------------
# App Runner service running the container image, wired to RDS + the LLM key.
# ---------------------------------------------------------------------------
resource "aws_apprunner_service" "api" {
  service_name = var.project_name

  source_configuration {
    image_repository {
      image_identifier      = "${aws_ecr_repository.api.repository_url}:latest"
      image_repository_type = "ECR"
      image_configuration {
        port = "8000"
        runtime_environment_variables = {
          ENVIRONMENT       = "production"
          DATABASE_URL      = "postgresql+psycopg2://${var.db_username}:${var.db_password}@${aws_db_instance.postgres.endpoint}/patientflow"
          ANTHROPIC_API_KEY = var.anthropic_api_key
          LLM_STUB_MODE     = "false"
        }
      }
    }
    auto_deployments_enabled = true
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_ecr.arn
    }
  }

  health_check_configuration {
    protocol = "HTTP"
    path     = "/health"
  }
}

# IAM role letting App Runner pull from ECR.
resource "aws_iam_role" "apprunner_ecr" {
  name = "${var.project_name}-apprunner-ecr"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "build.apprunner.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr" {
  role       = aws_iam_role.apprunner_ecr.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}
