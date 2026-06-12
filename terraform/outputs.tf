##############################################################################
# outputs.tf  –  Root module outputs (Minggu 3 Update)
##############################################################################

# ─── Networking ───────────────────────────────────────────────────────────────

output "vpc_id" {
  description = "Self-link VPC yang dibuat"
  value       = module.networking.vpc_id
}

output "vpc_name" {
  description = "Nama VPC"
  value       = module.networking.vpc_name
}

output "subnet_id" {
  description = "Self-link subnet utama"
  value       = module.networking.subnet_id
}

output "vpc_connector_name" {
  description = "Nama VPC connector untuk Cloud Run"
  value       = module.networking.vpc_connector_name
}

# ─── IAM ──────────────────────────────────────────────────────────────────────

output "cloudrun_sa_email" {
  description = "Email service account Cloud Run"
  value       = module.iam.cloudrun_sa_email
}

output "pubsub_sa_email" {
  description = "Email service account Pub/Sub"
  value       = module.iam.pubsub_sa_email
}

output "cloudsql_sa_email" {
  description = "Email service account Cloud SQL"
  value       = module.iam.cloudsql_sa_email
}

# ─── Database ─────────────────────────────────────────────────────────────────

output "db_instance_name" {
  description = "Nama instance Cloud SQL"
  value       = module.database.instance_name
}

output "db_connection_name" {
  description = "Connection name Cloud SQL (project:region:instance)"
  value       = module.database.instance_connection_name
}

output "db_private_ip" {
  description = "Private IP Cloud SQL instance"
  value       = module.database.private_ip_address
  sensitive   = true
}

# ─── Storage ──────────────────────────────────────────────────────────────────

output "storage_bucket_name" {
  description = "Nama bucket sensor log"
  value       = module.storage.bucket_name
}

output "storage_bucket_url" {
  description = "URL bucket sensor log"
  value       = module.storage.bucket_url
}

# ─── Pub/Sub ──────────────────────────────────────────────────────────────────

output "pubsub_sensor_topic" {
  description = "Nama topik data sensor"
  value       = module.pubsub.sensor_topic_name
}

output "pubsub_alert_topic" {
  description = "Nama topik alert"
  value       = module.pubsub.alert_topic_name
}

output "pubsub_cloudrun_subscription" {
  description = "Nama subscription push ke Cloud Run"
  value       = module.pubsub.cloudrun_subscription_name
}

# ─── Artifact Registry (BARU — Minggu 3) ──────────────────────────────────────

output "artifact_registry_url" {
  description = "Base URL Artifact Registry"
  value       = module.artifact_registry.image_base_url
}

output "sensor_processor_image_url" {
  description = "URL lengkap image sensor-processor"
  value       = module.artifact_registry.sensor_processor_image
}

# ─── Cloud Run (BARU — Minggu 3) ──────────────────────────────────────────────

output "cloudrun_service_url" {
  description = "URL HTTPS endpoint Cloud Run sensor-processor"
  value       = module.cloudrun.service_url
}

output "cloudrun_service_name" {
  description = "Nama Cloud Run service"
  value       = module.cloudrun.service_name
}

output "cloudrun_ingress" {
  description = "Ingress setting Cloud Run (konfirmasi internal-only)"
  value       = module.cloudrun.ingress_setting
}

# ─── Secrets ──────────────────────────────────────────────────────────────────

output "secret_db_password_id" {
  description = "Secret ID untuk db-password"
  value       = module.secrets.db_password_secret_id
}

output "secret_db_connection_string_id" {
  description = "Secret ID untuk db-connection-string"
  value       = module.secrets.db_connection_string_secret_id
}

# ─── Summary Output ───────────────────────────────────────────────────────────

output "deployment_summary" {
  description = "Ringkasan deployment Minggu 3"
  value = {
    project_id          = var.project_id
    region              = var.region
    cloudrun_url        = module.cloudrun.service_url
    pubsub_sensor_topic = module.pubsub.sensor_topic_name
    database_instance   = module.database.instance_name
    storage_bucket      = module.storage.bucket_name
    registry_url        = module.artifact_registry.image_base_url
    minggu              = "3"
  }
}

# ─── Monitoring (BARU — Minggu 4) ─────────────────────────────────────────────

output "monitoring_dashboard_id" {
  description = "ID dashboard Cloud Monitoring"
  value       = module.monitoring.dashboard_name
}

output "notification_channel" {
  description = "Nama notification channel email"
  value       = module.monitoring.notification_channel_name
}

output "alert_policies" {
  description = "Ringkasan semua alert policy yang aktif"
  value = {
    cpu_high     = module.monitoring.alert_policy_cpu
    error_rate   = module.monitoring.alert_policy_error_rate
    disk_high    = module.monitoring.alert_policy_disk
    latency_high = module.monitoring.alert_policy_latency
    pubsub_backlog = module.monitoring.alert_policy_pubsub
  }
}

output "uptime_check_id" {
  description = "ID uptime check Cloud Run"
  value       = module.monitoring.uptime_check_id
}

# ─── Backup (BARU — Minggu 4) ─────────────────────────────────────────────────

output "backup_bucket_name" {
  description = "Nama bucket backup Cloud SQL"
  value       = module.backup.backup_bucket_name
}

output "backup_daily_job" {
  description = "Nama Cloud Scheduler job backup harian"
  value       = module.backup.daily_export_job_name
}

output "backup_weekly_job" {
  description = "Nama Cloud Scheduler job export mingguan CSV"
  value       = module.backup.weekly_csv_export_job_name
}

# ─── Security (BARU — Minggu 4) ───────────────────────────────────────────────

output "scc_findings_topic" {
  description = "Topik Pub/Sub untuk SCC security findings"
  value       = module.security.scc_topic_name
}

output "binary_auth_attestor" {
  description = "Nama Binary Authorization attestor"
  value       = module.security.binary_auth_attestor
}

# ─── Full Deployment Summary Minggu 4 ─────────────────────────────────────────

output "minggu4_deployment_summary" {
  description = "Ringkasan lengkap deployment Minggu 4"
  value = {
    project_id             = var.project_id
    region                 = var.region
    cloudrun_url           = module.cloudrun.service_url
    monitoring_dashboard   = module.monitoring.dashboard_name
    backup_bucket          = module.backup.backup_bucket_name
    alert_email            = var.alert_email
    total_alert_policies   = 7
    total_modules          = 9
    minggu                 = "4"
  }
}
