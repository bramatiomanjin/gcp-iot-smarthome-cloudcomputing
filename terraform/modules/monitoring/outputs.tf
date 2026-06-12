##############################################################################
# modules/monitoring/outputs.tf
##############################################################################

output "notification_channel_name" {
  description = "Nama notification channel email"
  value       = google_monitoring_notification_channel.email_alert.name
}

output "dashboard_name" {
  description = "Nama monitoring dashboard"
  value       = google_monitoring_dashboard.smarthome_dashboard.id
}

output "alert_policy_cpu" {
  description = "Alert policy CPU Cloud Run"
  value       = google_monitoring_alert_policy.cloudrun_cpu_high.name
}

output "alert_policy_error_rate" {
  description = "Alert policy error rate Cloud Run"
  value       = google_monitoring_alert_policy.cloudrun_error_rate_high.name
}

output "alert_policy_disk" {
  description = "Alert policy disk Cloud SQL"
  value       = google_monitoring_alert_policy.cloudsql_disk_high.name
}

output "alert_policy_latency" {
  description = "Alert policy latency Cloud Run"
  value       = google_monitoring_alert_policy.cloudrun_latency_high.name
}

output "alert_policy_pubsub" {
  description = "Alert policy Pub/Sub backlog"
  value       = google_monitoring_alert_policy.pubsub_backlog_high.name
}

output "uptime_check_id" {
  description = "ID uptime check Cloud Run"
  value       = google_monitoring_uptime_check_config.cloudrun_health.uptime_check_id
}

output "log_sink_cloudrun" {
  description = "Nama log sink Cloud Run ke GCS"
  value       = google_logging_project_sink.cloudrun_logs_to_gcs.name
}

output "log_sink_security" {
  description = "Nama log sink security audit ke GCS"
  value       = google_logging_project_sink.security_logs_to_gcs.name
}
