resource "google_project_iam_audit_config" "smarthome_audit" {
  project = var.project_id
  service = "allServices"

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_storage_bucket" "audit_log_bucket" {
  name          = "${var.project_id}-audit-logs"
  location      = var.region
  storage_class = "COLDLINE"

  retention_policy {
    retention_period = 2592000
  }

  lifecycle_rule {
    action { type = "Delete" }
    condition { age = 90 }
  }

  uniform_bucket_level_access = true
  project                     = var.project_id
}

resource "google_logging_project_sink" "audit_sink" {
  name        = "smarthome-audit-sink"
  destination = "storage.googleapis.com/${google_storage_bucket.audit_log_bucket.name}"
  project     = var.project_id
  filter      = "logName=~\"projects/${var.project_id}/logs/cloudaudit.googleapis.com\""

  unique_writer_identity = true
}