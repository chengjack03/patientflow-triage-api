variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "patientflow-triage-api"
}

variable "db_username" {
  description = "Master username for the RDS Postgres instance"
  type        = string
  default     = "pfadmin"
}

variable "db_password" {
  description = "Master password for RDS. Pass via TF_VAR_db_password, never commit it."
  type        = string
  sensitive   = true
}

variable "anthropic_api_key" {
  description = "Anthropic API key injected into the App Runner service env."
  type        = string
  sensitive   = true
}
