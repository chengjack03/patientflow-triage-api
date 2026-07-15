output "ecr_repository_url" {
  description = "Push container images here"
  value       = aws_ecr_repository.api.repository_url
}

output "service_url" {
  description = "Public URL of the deployed API"
  value       = "https://${aws_apprunner_service.api.service_url}"
}

output "db_endpoint" {
  description = "RDS Postgres endpoint"
  value       = aws_db_instance.postgres.endpoint
}
