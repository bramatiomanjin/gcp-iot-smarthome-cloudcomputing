##############################################################################
# modules/iam/outputs.tf
##############################################################################

output "cloudrun_sa_email" {
  description = "Email service account Cloud Run Processor"
  value       = google_service_account.cloudrun_sa.email
}

output "cloudrun_sa_id" {
  description = "ID service account Cloud Run Processor"
  value       = google_service_account.cloudrun_sa.id
}

output "pubsub_sa_email" {
  description = "Email service account Pub/Sub Invoker"
  value       = google_service_account.pubsub_sa.email
}

output "cloudsql_sa_email" {
  description = "Email service account Cloud SQL"
  value       = google_service_account.cloudsql_sa.email
}

output "monitoring_sa_email" {
  description = "Email service account Monitoring"
  value       = google_service_account.monitoring_sa.email
}

output "cicd_sa_email" {
  description = "Email service account CI/CD"
  value       = google_service_account.cicd_sa.email
}
