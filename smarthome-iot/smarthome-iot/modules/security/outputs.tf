##############################################################################
# modules/security/outputs.tf
##############################################################################

output "scc_topic_name" {
  value       = google_pubsub_topic.scc_findings_topic.name
  description = "Nama topik Pub/Sub untuk SCC findings"
}

output "binary_auth_attestor" {
  value       = google_binary_authorization_attestor.build_attestor.name
  description = "Nama Binary Authorization attestor"
}

output "iam_change_alert_policy" {
  value       = google_monitoring_alert_policy.iam_change_alert.name
  description = "Nama alert policy perubahan IAM"
}
