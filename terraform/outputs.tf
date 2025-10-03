output "github_connection_arn" {
  description = "GitHub connection ARN"
  value       = var.use_existing_github_connection ? data.aws_apprunner_connection.github[0].arn : aws_apprunner_connection.github[0].arn
}

output "github_connection_status" {
  description = "GitHub connection status"
  value       = var.use_existing_github_connection ? data.aws_apprunner_connection.github[0].status : aws_apprunner_connection.github[0].status
}

output "apprunner_service_url" {
  description = "App Runner service URL"
  value       = aws_apprunner_service.admin_dashboard_backend.service_url
}

output "apprunner_service_arn" {
  description = "App Runner service ARN"
  value       = aws_apprunner_service.admin_dashboard_backend.arn
}

output "apprunner_service_id" {
  description = "App Runner service ID"
  value       = aws_apprunner_service.admin_dashboard_backend.service_id
}

output "apprunner_service_status" {
  description = "App Runner service status"
  value       = aws_apprunner_service.admin_dashboard_backend.status
}

output "custom_domain_status" {
  description = "Custom domain association status"
  value       = var.custom_domain != "" ? aws_apprunner_custom_domain_association.main[0].status : "Not configured"
}

output "custom_domain_dns_target" {
  description = "DNS target for custom domain (CNAME record)"
  value       = var.custom_domain != "" ? aws_apprunner_custom_domain_association.main[0].dns_target : "Not configured"
}
