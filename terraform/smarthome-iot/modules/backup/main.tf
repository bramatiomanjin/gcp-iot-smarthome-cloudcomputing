##############################################################################
# modules/backup/main.tf
# Backup Otomatis & Disaster Recovery
#
# Komponen:
#   1. Cloud SQL export ke GCS via Cloud Scheduler + Cloud Run job
#   2. Bucket khusus backup (terpisah dari bucket log sensor)
#   3. IAM permission untuk export
#   4. Lifecycle policy bucket backup
#   5. Backup verification job (mingguan)
##############################################################################

# ─── 1. Bucket Khusus Backup ─────────────────────────────────────────────────
# Terpisah dari bucket sensor log agar akses dan lifecycle berbeda

resource "google_storage_bucket" "backup_bucket" {
  name          = "${var.project_id}-smarthome-db-backup"
  project       = var.project_id
  location      = var.region
  storage_class = "NEARLINE"   # Backup tidak sering diakses — Nearline lebih hemat

  labels = var.labels

  # Keamanan: tidak ada akses publik
  public_access_prevention = "enforced"
  uniform_bucket_level_access = true

  # Enkripsi CMEK (sama dengan database)
  dynamic "encryption" {
    for_each = var.kms_key_id != "" ? [1] : []
    content {
      default_kms_key_name = var.kms_key_id
    }
  }

  # Versioning untuk recovery
  versioning {
    enabled = true
  }

  # Lifecycle: hapus backup lama otomatis
  lifecycle_rule {
    action { type = "Delete" }
    condition {
      age = 30   # Hapus backup yang lebih dari 30 hari
    }
  }

  # Transisi ke Coldline setelah 7 hari (lebih murah)
  lifecycle_rule {
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
    condition {
      age = 7
    }
  }
}

# ─── 2. IAM: Cloud SQL SA bisa write ke backup bucket ───────────────────────

resource "google_storage_bucket_iam_member" "cloudsql_backup_writer" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.cloudsql_sa_email}"
}

# Cloud SQL Service Account built-in GCP juga butuh akses
resource "google_storage_bucket_iam_member" "cloudsql_builtin_backup" {
  bucket = google_storage_bucket.backup_bucket.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:service-${var.project_number}@gcp-sa-cloud-sql.iam.gserviceaccount.com"
}

# ─── 3. Service Account untuk Cloud Scheduler Jobs ────────────────────────────

resource "google_service_account" "scheduler_sa" {
  project      = var.project_id
  account_id   = "sa-backup-scheduler"
  display_name = "Backup Scheduler SA"
  description  = "Service account untuk Cloud Scheduler yang memicu export backup Cloud SQL"
}

# Scheduler SA boleh invoke Cloud Run backup job
resource "google_project_iam_member" "scheduler_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.scheduler_sa.email}"
}

# Scheduler SA boleh export dari Cloud SQL
resource "google_project_iam_member" "scheduler_cloudsql_viewer" {
  project = var.project_id
  role    = "roles/cloudsql.viewer"
  member  = "serviceAccount:${google_service_account.scheduler_sa.email}"
}

# ─── 4. Cloud Scheduler: Daily SQL Export ────────────────────────────────────
# Setiap hari pukul 03:00 WIB (20:00 UTC — Asia/Jakarta = UTC+7)

resource "google_cloud_scheduler_job" "daily_db_export" {
  project     = var.project_id
  region      = var.region
  name        = "smarthome-daily-db-export"
  description = "Ekspor database smarthome ke Cloud Storage setiap hari pukul 03:00 WIB"
  schedule    = "0 20 * * *"   # Cron: jam 20:00 UTC = 03:00 WIB
  time_zone   = "Asia/Jakarta"

  http_target {
    http_method = "POST"
    uri         = "https://sqladmin.googleapis.com/sql/v1beta4/projects/${var.project_id}/instances/${var.db_instance_name}/export"

    body = base64encode(jsonencode({
      exportContext = {
        kind      = "sql#exportContext"
        fileType  = "SQL"
        uri       = "gs://${google_storage_bucket.backup_bucket.name}/exports/daily/smarthome-backup-{{.YYYY}}-{{.MM}}-{{.DD}}.sql"
        databases = [var.db_name]
        sqlExportOptions = {
          schemaOnly = false
          mysqlExportOptions = {
            masterData = 0
          }
        }
      }
    }))

    oauth_token {
      service_account_email = google_service_account.scheduler_sa.email
      scope                 = "https://www.googleapis.com/auth/sqlservice.admin"
    }
  }

  retry_config {
    retry_count          = 3
    min_backoff_duration = "5s"
    max_backoff_duration = "3600s"
    max_doublings        = 5
  }

  attempt_deadline = "1800s"   # Timeout 30 menit untuk export besar
}

# ─── 5. Cloud Scheduler: Weekly CSV Export (Data Analytics) ─────────────────
# Ekspor data sensor ke CSV setiap Minggu pukul 01:00 WIB

resource "google_cloud_scheduler_job" "weekly_csv_export" {
  project     = var.project_id
  region      = var.region
  name        = "smarthome-weekly-csv-export"
  description = "Ekspor data sensor_data ke CSV mingguan untuk arsip analitik"
  schedule    = "0 18 * * 0"   # Setiap Minggu jam 18:00 UTC = 01:00 WIB
  time_zone   = "Asia/Jakarta"

  http_target {
    http_method = "POST"
    uri         = "https://sqladmin.googleapis.com/sql/v1beta4/projects/${var.project_id}/instances/${var.db_instance_name}/export"

    body = base64encode(jsonencode({
      exportContext = {
        kind      = "sql#exportContext"
        fileType  = "CSV"
        uri       = "gs://${google_storage_bucket.backup_bucket.name}/exports/weekly/sensor-data-weekly.csv"
        databases = [var.db_name]
        csvExportOptions = {
          selectQuery = "SELECT * FROM smarthome.sensor_data WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)"
        }
      }
    }))

    oauth_token {
      service_account_email = google_service_account.scheduler_sa.email
      scope                 = "https://www.googleapis.com/auth/sqlservice.admin"
    }
  }
}

# ─── 6. Alert: Backup Job Gagal ──────────────────────────────────────────────
# Monitor log Cloud Scheduler untuk job failure

resource "google_logging_metric" "backup_job_failure" {
  project     = var.project_id
  name        = "backup/scheduler_job_failure"
  description = "Mendeteksi kegagalan Cloud Scheduler backup job"
  filter      = <<-EOT
    resource.type="cloud_scheduler_job"
    AND (resource.labels.job_id="smarthome-daily-db-export"
         OR resource.labels.job_id="smarthome-weekly-csv-export")
    AND jsonPayload.status="FAILED"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_monitoring_alert_policy" "backup_failure_alert" {
  project      = var.project_id
  display_name = "[SmartHome] Backup Job Gagal"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Cloud Scheduler backup job gagal"
    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/backup/scheduler_job_failure\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"   # Alert langsung saat ada satu kegagalan
      aggregations {
        alignment_period   = "3600s"
        per_series_aligner = "ALIGN_COUNT"
      }
    }
  }

  notification_channels = [var.notification_channel_name]

  documentation {
    content   = "**Backup job gagal!** Periksa log Cloud Scheduler dan pastikan Cloud SQL instance berjalan normal."
    mime_type = "text/markdown"
  }
}
