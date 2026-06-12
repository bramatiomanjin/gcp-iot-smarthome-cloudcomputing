##############################################################################
# modules/monitoring/main.tf
# Cloud Monitoring & Logging — Observabilitas penuh sistem IoT
#
# Isi modul ini:
#   1. Notification Channel (Email)
#   2. Log-based Metrics (custom)
#   3. Alert Policies (5 rules: CPU, Error Rate, Disk, Latency, Pub/Sub backlog)
#   4. Monitoring Dashboard (JSON)
#   5. Log Sinks ke Cloud Storage (centralized logging)
#   6. Log Exclusion Filters (noise reduction)
##############################################################################

# ─── 1. Notification Channel ─────────────────────────────────────────────────

resource "google_monitoring_notification_channel" "email_alert" {
  project      = var.project_id
  display_name = "SmartHome IoT — Email Alert"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
  user_labels = var.labels
}

# Slack webhook (opsional — aktifkan jika tersedia)
# resource "google_monitoring_notification_channel" "slack" { ... }

# ─── 2. Log-Based Metrics ────────────────────────────────────────────────────
# Metrik custom dari log Cloud Run untuk error rate alerting

resource "google_logging_metric" "cloudrun_error_count" {
  project     = var.project_id
  name        = "cloudrun/sensor_processor_error_count"
  description = "Jumlah error HTTP 5xx dari Cloud Run sensor-processor"
  filter      = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${var.cloudrun_service_name}"
    httpRequest.status>=500
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    labels {
      key         = "status_code"
      value_type  = "STRING"
      description = "HTTP status code"
    }
  }

  label_extractors = {
    "status_code" = "EXTRACT(httpRequest.status)"
  }
}

resource "google_logging_metric" "pubsub_nack_count" {
  project     = var.project_id
  name        = "pubsub/sensor_message_nack_count"
  description = "Jumlah pesan Pub/Sub yang di-NACK oleh Cloud Run"
  filter      = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${var.cloudrun_service_name}"
    jsonPayload.message="message_nacked"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_logging_metric" "anomaly_alert_count" {
  project     = var.project_id
  name        = "iot/anomaly_alert_count"
  description = "Jumlah anomali sensor yang terdeteksi dan memicu alert"
  filter      = <<-EOT
    resource.type="cloud_run_revision"
    resource.labels.service_name="${var.cloudrun_service_name}"
    jsonPayload.event="anomaly_detected"
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    labels {
      key         = "sensor_type"
      value_type  = "STRING"
      description = "Tipe sensor (temperature/motion)"
    }
  }

  label_extractors = {
    "sensor_type" = "EXTRACT(jsonPayload.sensor_type)"
  }
}

# ─── 3. Alert Policies ───────────────────────────────────────────────────────

# Alert 1: Cloud Run CPU Usage > 80%
resource "google_monitoring_alert_policy" "cloudrun_cpu_high" {
  project      = var.project_id
  display_name = "[SmartHome] Cloud Run CPU Usage > 80%"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Cloud Run CPU utilization tinggi"
    condition_threshold {
      filter          = <<-EOT
        resource.type="cloud_run_revision"
        AND resource.labels.service_name="${var.cloudrun_service_name}"
        AND metric.type="run.googleapis.com/container/cpu/utilizations"
      EOT
      comparison      = "COMPARISON_GT"
      threshold_value = 0.80   # 80%
      duration        = "300s" # Bertahan 5 menit sebelum alert

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.service_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email_alert.name]

  alert_strategy {
    auto_close = "1800s" # Auto-close setelah 30 menit kondisi normal
  }

  documentation {
    content   = <<-EOT
      **Alert: Cloud Run CPU Usage Tinggi**

      Service `${var.cloudrun_service_name}` menggunakan CPU di atas 80% selama lebih dari 5 menit.

      **Kemungkinan penyebab:**
      - Lonjakan pesan sensor yang tidak normal
      - Memory leak pada aplikasi
      - Query Cloud SQL yang berat

      **Tindakan:**
      1. Cek log Cloud Run: `gcloud logging read "resource.type=cloud_run_revision"`
      2. Periksa metrik request rate di dashboard
      3. Pertimbangkan meningkatkan max_instances atau CPU limit
    EOT
    mime_type = "text/markdown"
  }
}

# Alert 2: Cloud Run Error Rate > 5%
resource "google_monitoring_alert_policy" "cloudrun_error_rate_high" {
  project      = var.project_id
  display_name = "[SmartHome] Cloud Run Error Rate > 5%"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Error rate Cloud Run tinggi"
    condition_threshold {
      filter          = <<-EOT
        resource.type="cloud_run_revision"
        AND resource.labels.service_name="${var.cloudrun_service_name}"
        AND metric.type="run.googleapis.com/request_count"
        AND metric.labels.response_code_class="5xx"
      EOT
      comparison      = "COMPARISON_GT"
      threshold_value = 5   # > 5 error 5xx per menit
      duration        = "180s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.service_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email_alert.name]

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    content   = <<-EOT
      **Alert: Cloud Run Error Rate Tinggi**

      Service `${var.cloudrun_service_name}` menghasilkan lebih dari 5 error 5xx per menit.

      **Kemungkinan penyebab:**
      - Koneksi Cloud SQL gagal (connection pool exhausted)
      - Secret Manager tidak dapat diakses
      - Pesan Pub/Sub dalam format tidak valid

      **Tindakan:**
      1. Cek log error: `gcloud logging read "severity=ERROR"`
      2. Verifikasi koneksi Cloud SQL masih aktif
      3. Cek status Secret Manager
    EOT
    mime_type = "text/markdown"
  }
}

# Alert 3: Cloud SQL Disk Usage > 90%
resource "google_monitoring_alert_policy" "cloudsql_disk_high" {
  project      = var.project_id
  display_name = "[SmartHome] Cloud SQL Disk Usage > 90%"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Cloud SQL disk hampir penuh"
    condition_threshold {
      filter          = <<-EOT
        resource.type="cloudsql_database"
        AND resource.labels.database_id="${var.project_id}:${var.db_instance_name}"
        AND metric.type="cloudsql.googleapis.com/database/disk/utilization"
      EOT
      comparison      = "COMPARISON_GT"
      threshold_value = 0.90   # 90%
      duration        = "60s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email_alert.name]

  alert_strategy {
    auto_close = "86400s" # 24 jam
  }

  documentation {
    content   = <<-EOT
      **Alert: Cloud SQL Disk Hampir Penuh**

      Instance Cloud SQL `${var.db_instance_name}` menggunakan lebih dari 90% kapasitas disk.

      **Tindakan segera:**
      1. Cek ukuran tabel: `SELECT table_name, ROUND((data_length + index_length) / 1024 / 1024, 2) AS size_mb FROM information_schema.tables WHERE table_schema = 'smarthome';`
      2. Archive data sensor lama ke Cloud Storage
      3. Aktifkan disk_autoresize jika belum aktif (sudah dikonfigurasi di Terraform)
    EOT
    mime_type = "text/markdown"
  }
}

# Alert 4: Cloud Run Request Latency > 5 detik
resource "google_monitoring_alert_policy" "cloudrun_latency_high" {
  project      = var.project_id
  display_name = "[SmartHome] Cloud Run Latency > 5 Detik (p99)"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Latency Cloud Run tinggi"
    condition_threshold {
      filter          = <<-EOT
        resource.type="cloud_run_revision"
        AND resource.labels.service_name="${var.cloudrun_service_name}"
        AND metric.type="run.googleapis.com/request_latencies"
      EOT
      comparison      = "COMPARISON_GT"
      threshold_value = 5000   # 5000 ms = 5 detik
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_PERCENTILE_99"
        cross_series_reducer = "REDUCE_MEAN"
        group_by_fields      = ["resource.labels.service_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email_alert.name]

  alert_strategy {
    auto_close = "1800s"
  }

  documentation {
    content   = <<-EOT
      **Alert: Latency Cloud Run Tinggi (p99)**

      99th percentile latency lebih dari 5 detik. Pub/Sub berpotensi timeout dan retry.

      **Tindakan:**
      1. Cek apakah Cloud SQL query lambat (slow query log)
      2. Cek koneksi pool di aplikasi
      3. Pertimbangkan `startup_cpu_boost = true`
    EOT
    mime_type = "text/markdown"
  }
}

# Alert 5: Pub/Sub Undelivered Messages > 1000
resource "google_monitoring_alert_policy" "pubsub_backlog_high" {
  project      = var.project_id
  display_name = "[SmartHome] Pub/Sub Undelivered Messages > 1000"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Pub/Sub message backlog tinggi"
    condition_threshold {
      filter          = <<-EOT
        resource.type="pubsub_subscription"
        AND metric.type="pubsub.googleapis.com/subscription/num_undelivered_messages"
      EOT
      comparison      = "COMPARISON_GT"
      threshold_value = 1000
      duration        = "300s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_MEAN"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.labels.subscription_id"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email_alert.name]

  alert_strategy {
    auto_close = "3600s"
  }

  documentation {
    content   = <<-EOT
      **Alert: Pub/Sub Backlog Tinggi**

      Terdapat lebih dari 1000 pesan yang belum terkirim ke Cloud Run.

      **Kemungkinan penyebab:**
      - Cloud Run mengalami gangguan (cek alert Cloud Run)
      - Pesan di dead-letter topic menumpuk
      - Throughput sensor meningkat drastis

      **Tindakan:**
      1. Cek status Cloud Run: `gcloud run services describe sensor-processor`
      2. Periksa dead-letter topic
      3. Cek log Cloud Run untuk error
    EOT
    mime_type = "text/markdown"
  }
}

# ─── 4. Monitoring Dashboard ─────────────────────────────────────────────────

resource "google_monitoring_dashboard" "smarthome_dashboard" {
  project        = var.project_id
  dashboard_json = jsonencode({
    displayName = "SmartHome IoT — Monitoring Dashboard"
    mosaicLayout = {
      columns = 12
      tiles   = [
        # Row 1: Header tiles — Cloud Run health
        {
          width  = 6
          height = 4
          widget = {
            title = "Cloud Run — Request Rate (req/min)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.cloudrun_service_name}\" AND metric.type=\"run.googleapis.com/request_count\""
                    aggregation = {

                      alignmentPeriod = "60s"

                      perSeriesAligner = "ALIGN_RATE"

                    }
                  }
                }
                plotType = "LINE"
              }]
              yAxis = {

                label = "req/min"

                scale = "LINEAR"

              }
            }
          }
        },
        {
          xPos   = 6
          width  = 6
          height = 4
          widget = {
            title = "Cloud Run — Error Rate (5xx/min)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.cloudrun_service_name}\" AND metric.type=\"run.googleapis.com/request_count\" AND metric.labels.response_code_class=\"5xx\""
                    aggregation = {

                      alignmentPeriod = "60s"

                      perSeriesAligner = "ALIGN_RATE"

                    }
                  }
                }
                plotType = "LINE"
              }]
              yAxis = {

                label = "error/min"

                scale = "LINEAR"

              }
            }
          }
        },
        # Row 2: Latency & CPU
        {
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Cloud Run — Request Latency p50/p95/p99 (ms)"
            xyChart = {
              dataSets = [
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.cloudrun_service_name}\" AND metric.type=\"run.googleapis.com/request_latencies\""
                      aggregation = {

                        alignmentPeriod = "60s"

                        perSeriesAligner = "ALIGN_PERCENTILE_50"

                      }
                    }
                  }
                  plotType = "LINE"
                  legendTemplate = "p50"
                },
                {
                  timeSeriesQuery = {
                    timeSeriesFilter = {
                      filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.cloudrun_service_name}\" AND metric.type=\"run.googleapis.com/request_latencies\""
                      aggregation = {

                        alignmentPeriod = "60s"

                        perSeriesAligner = "ALIGN_PERCENTILE_99"

                      }
                    }
                  }
                  plotType = "LINE"
                  legendTemplate = "p99"
                }
              ]
              yAxis = {

                label = "ms"

                scale = "LINEAR"

              }
            }
          }
        },
        {
          xPos   = 6
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Cloud Run — CPU Utilization (%)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.cloudrun_service_name}\" AND metric.type=\"run.googleapis.com/container/cpu/utilizations\""
                    aggregation = {

                      alignmentPeriod = "60s"

                      perSeriesAligner = "ALIGN_MEAN"

                    }
                  }
                }
                plotType = "LINE"
              }]
              thresholds = [{

                  value = 0.8

                  label = "80% threshold"

                  color = "RED"

              }]
              yAxis = {

                label = "utilization"

                scale = "LINEAR"

              }
            }
          }
        },
        # Row 3: Cloud SQL metrics
        {
          yPos   = 8
          width  = 4
          height = 4
          widget = {
            title = "Cloud SQL — Connections"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/postgresql/num_backends\""
                    aggregation = {

                      alignmentPeriod = "60s"

                      perSeriesAligner = "ALIGN_MEAN"

                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        },
        {
          xPos   = 4
          yPos   = 8
          width  = 4
          height = 4
          widget = {
            title = "Cloud SQL — Disk Utilization (%)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloudsql_database\" AND metric.type=\"cloudsql.googleapis.com/database/disk/utilization\""
                    aggregation = {

                      alignmentPeriod = "60s"

                      perSeriesAligner = "ALIGN_MEAN"

                    }
                  }
                }
                plotType = "LINE"
              }]
              thresholds = [{

                  value = 0.9

                  label = "90% threshold"

                  color = "RED"

              }]
            }
          }
        },
        {
          xPos   = 8
          yPos   = 8
          width  = 4
          height = 4
          widget = {
            title = "Pub/Sub — Undelivered Messages"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"pubsub_subscription\" AND metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\""
                    aggregation = {

                      alignmentPeriod = "60s"

                      perSeriesAligner = "ALIGN_MEAN"

                    }
                  }
                }
                plotType = "LINE"
              }]
              thresholds = [{

                  value = 1000

                  label = "1000 backlog"

                  color = "YELLOW"

              }]
            }
          }
        },
        # Row 4: IoT custom metrics
        {
          yPos   = 12
          width  = 6
          height = 4
          widget = {
            title = "IoT — Anomaly Alert Count (per jam)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "metric.type=\"logging.googleapis.com/user/iot/anomaly_alert_count\""
                    aggregation = {

                      alignmentPeriod = "3600s"

                      perSeriesAligner = "ALIGN_SUM"

                    }
                  }
                }
                plotType = "STACKED_BAR"
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 12
          width  = 6
          height = 4
          widget = {
            title = "Cloud Run — Active Instances"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"cloud_run_revision\" AND resource.labels.service_name=\"${var.cloudrun_service_name}\" AND metric.type=\"run.googleapis.com/container/instance_count\""
                    aggregation = {

                      alignmentPeriod = "60s"

                      perSeriesAligner = "ALIGN_MEAN"

                    }
                  }
                }
                plotType = "LINE"
              }]
            }
          }
        }
      ]
    }
  })
}

# ─── 5. Log Sinks (Centralized Logging ke Cloud Storage) ─────────────────────

resource "google_logging_project_sink" "cloudrun_logs_to_gcs" {
  project                = var.project_id
  name                   = "sink-cloudrun-logs-to-gcs"
  description            = "Export log Cloud Run sensor-processor ke Cloud Storage untuk audit trail"
  destination            = "storage.googleapis.com/${var.log_bucket_name}"
  unique_writer_identity = true

  filter = <<-EOT
    resource.type="cloud_run_revision"
    AND resource.labels.service_name="${var.cloudrun_service_name}"
    AND severity>=WARNING
  EOT
}

resource "google_logging_project_sink" "cloudsql_logs_to_gcs" {
  project                = var.project_id
  name                   = "sink-cloudsql-logs-to-gcs"
  description            = "Export log Cloud SQL ke Cloud Storage untuk audit trail"
  destination            = "storage.googleapis.com/${var.log_bucket_name}"
  unique_writer_identity = true

  filter = <<-EOT
    resource.type="cloudsql_database"
    AND severity>=WARNING
  EOT
}

resource "google_logging_project_sink" "security_logs_to_gcs" {
  project                = var.project_id
  name                   = "sink-security-logs-to-gcs"
  description            = "Export semua log security/audit ke Cloud Storage"
  destination            = "storage.googleapis.com/${var.log_bucket_name}"
  unique_writer_identity = true

  filter = <<-EOT
    logName:"cloudaudit.googleapis.com"
    OR logName:"logging.googleapis.com/activity"
    OR protoPayload.serviceName="secretmanager.googleapis.com"
    OR protoPayload.serviceName="iam.googleapis.com"
  EOT
}

# ─── Grant sink writer access ke bucket ──────────────────────────────────────

resource "google_storage_bucket_iam_member" "sink_cloudrun_writer" {
  bucket = var.log_bucket_name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.cloudrun_logs_to_gcs.writer_identity
}

resource "google_storage_bucket_iam_member" "sink_cloudsql_writer" {
  bucket = var.log_bucket_name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.cloudsql_logs_to_gcs.writer_identity
}

resource "google_storage_bucket_iam_member" "sink_security_writer" {
  bucket = var.log_bucket_name
  role   = "roles/storage.objectCreator"
  member = google_logging_project_sink.security_logs_to_gcs.writer_identity
}

# ─── 6. Log Exclusion (Noise Reduction) ──────────────────────────────────────
# Kurangi volume log yang tidak penting agar hemat biaya logging

resource "google_logging_project_exclusion" "exclude_debug_logs" {
  project     = var.project_id
  name        = "exclude-debug-info-logs"
  description = "Kecualikan log level DEBUG dan INFO dari Cloud Run untuk mengurangi volume"
  filter      = <<-EOT
    resource.type="cloud_run_revision"
    AND resource.labels.service_name="${var.cloudrun_service_name}"
    AND severity=DEBUG
  EOT
}

# ─── 7. Uptime Check ─────────────────────────────────────────────────────────
# Cek kesehatan Cloud Run endpoint setiap 5 menit

resource "google_monitoring_uptime_check_config" "cloudrun_health" {
  project      = var.project_id
  display_name = "SmartHome Cloud Run Health Check"
  timeout      = "10s"
  period       = "300s"   # Setiap 5 menit

  http_check {
    path           = "/health"
    port           = 443
    use_ssl        = true
    validate_ssl   = true
    request_method = "GET"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.cloudrun_service_host   # domain Cloud Run tanpa https://
    }
  }
}

# Alert untuk uptime check gagal
resource "google_monitoring_alert_policy" "cloudrun_uptime_failed" {
  project      = var.project_id
  display_name = "[SmartHome] Cloud Run Health Check Gagal"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Uptime check gagal"
    condition_threshold {
      filter          = <<-EOT
        resource.type="uptime_url"
        AND metric.type="monitoring.googleapis.com/uptime_check/check_passed"
        AND metric.labels.check_id="${google_monitoring_uptime_check_config.cloudrun_health.uptime_check_id}"
      EOT
      comparison      = "COMPARISON_GT"
      threshold_value = 1
      duration        = "60s"

      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_NEXT_OLDER"
        cross_series_reducer = "REDUCE_COUNT_FALSE"
        group_by_fields      = ["resource.labels.host"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email_alert.name]

  documentation {
    content   = "**Cloud Run health check gagal!** Service `${var.cloudrun_service_name}` tidak merespons di endpoint /health."
    mime_type = "text/markdown"
  }
}

# ─── 7. Budget Alert — Batas Pengeluaran $5/bulan ─────────────────────────────
# Checklist Minggu 4: Budget alert untuk kontrol biaya
# Notifikasi dikirim ke email alert_email saat pengeluaran mendekati threshold

resource "google_billing_budget" "smarthome_budget" {
  # Hanya dibuat jika billing_account_id diisi di tfvars
  # Jalankan: gcloud billing accounts list  → isi billing_account_id di terraform.tfvars
  count = var.billing_account_id != "" ? 1 : 0

  billing_account = var.billing_account_id
  display_name    = "SmartHome IoT — Monthly Budget Alert"

  budget_filter {
    projects = ["projects/${var.project_number}"]
    services = []   # Semua service GCP
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = "5"   # $5/bulan — sesuai checklist
    }
  }

  # Alert pada 50%, 90%, 100% dari budget
  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }
  threshold_rules {
    threshold_percent = 0.9
    spend_basis       = "CURRENT_SPEND"
  }
  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  # Kirim email ke notification channel yang sudah ada
  all_updates_rule {
    monitoring_notification_channels = [
      google_monitoring_notification_channel.email_alert.id
    ]
    disable_default_iam_recipients = false
  }
}
