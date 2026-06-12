##############################################################################
# modules/backup/outputs.tf
##############################################################################

output "backup_bucket_name" {
  value       = google_storage_bucket.backup_bucket.name
  description = "Nama bucket backup Cloud SQL"
}

output "backup_bucket_url" {
  value       = google_storage_bucket.backup_bucket.url
  description = "URL bucket backup"
}

output "daily_export_job_name" {
  value       = google_cloud_scheduler_job.daily_db_export.name
  description = "Nama Cloud Scheduler job export harian"
}

output "weekly_csv_export_job_name" {
  value       = google_cloud_scheduler_job.weekly_csv_export.name
  description = "Nama Cloud Scheduler job export mingguan CSV"
}

output "scheduler_sa_email" {
  value       = google_service_account.scheduler_sa.email
  description = "Email service account backup scheduler"
}
