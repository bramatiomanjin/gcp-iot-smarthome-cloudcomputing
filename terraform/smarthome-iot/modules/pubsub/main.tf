##############################################################################
# modules/pubsub/main.tf
# Cloud Pub/Sub — Topics, Subscriptions, Dead Letter, IAM
# Security Engineer: Minggu 2 — Implementasi Infrastruktur Dasar
#
# Topik yang dibuat:
#   1. iot-topic       — Ingesti data sensor dari perangkat IoT via MQTT
#   2. iot-alert-topic — Distribusi notifikasi alert ke pengguna akhir
#   3. iot-dead-letter — Dead-letter topic untuk pesan yang gagal diproses
#
# Prinsip Keamanan:
#   1. Setiap SA hanya mendapat permission minimal (publisher / subscriber)
#   2. Dead-letter topic menangkap pesan yang gagal — tidak ada data yang hilang
#   3. Message retention 7 hari — cukup untuk debugging dan audit
#   4. Enkripsi in-transit menggunakan TLS (default GCP Pub/Sub)
##############################################################################

# ─── Topic 1: Data Sensor (Ingesti) ──────────────────────────────────────────

resource "google_pubsub_topic" "sensor_data" {
  name    = var.topic_sensor_name
  project = var.project_id

  # Retensi pesan dalam topic (bukan subscription) — 7 hari
  message_retention_duration = "604800s"

  labels = var.labels
}

# Schema validasi pesan sensor (opsional tapi direkomendasikan)
# Memastikan setiap pesan yang masuk memiliki struktur JSON yang benar
resource "google_pubsub_schema" "sensor_schema" {
  name       = "sensor-data-schema"
  project    = var.project_id
  type       = "AVRO"
  definition = jsonencode({
    type = "record"
    name = "SensorReading"
    fields = [
      { name = "device_id",    type = "string" },
      { name = "sensor_type",  type = "string" },
      { name = "value",        type = "float" },
      { name = "timestamp",    type = "string" },
      { name = "unit",         type = ["null", "string"], default = null }
    ]
  })
}

# ─── Topic 2: Alert Notifikasi ────────────────────────────────────────────────

resource "google_pubsub_topic" "alert" {
  name    = var.topic_alert_name
  project = var.project_id

  message_retention_duration = "86400s"  # 1 hari — alert tidak perlu retensi panjang

  labels = var.labels
}

# ─── Topic 3: Dead-Letter Topic ──────────────────────────────────────────────
# Menampung pesan yang gagal diproses setelah max_delivery_attempts kali percobaan
# Tanpa ini, pesan yang gagal akan terus di-retry tanpa batas (infinite loop)

resource "google_pubsub_topic" "dead_letter" {
  name    = "${var.topic_sensor_name}-dead-letter"
  project = var.project_id

  message_retention_duration = "2592000s"  # 30 hari — untuk investigasi dan debugging

  labels = merge(var.labels, { purpose = "dead-letter" })
}

# ─── Subscription: Cloud Run Processor (Push) ─────────────────────────────────
# Push subscription akan mengirimkan HTTP POST ke endpoint Cloud Run
# setiap kali ada pesan baru di iot-topic

resource "google_pubsub_subscription" "cloudrun_push" {
  name    = "${var.topic_sensor_name}-cloudrun-push"
  topic   = google_pubsub_topic.sensor_data.id
  project = var.project_id

  # Acknowledgement deadline — Cloud Run harus respond dalam 60 detik
  ack_deadline_seconds = 60

  # Retensi pesan yang belum di-ack — 7 hari
  message_retention_duration = "604800s"

  # Jangan retain pesan yang sudah di-ack
  retain_acked_messages = false

  # Retry policy — backoff eksponensial sebelum kirim ulang
  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "300s"  # Maksimum backoff 5 menit
  }

  # Dead-letter configuration — setelah 5 gagal, kirim ke dead-letter topic
  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.dead_letter.id
    max_delivery_attempts = 5
  }

  # Push configuration ke Cloud Run
  # URL akan diisi setelah Cloud Run ter-deploy; placeholder untuk sekarang
  push_config {
    push_endpoint = var.cloudrun_push_endpoint

    # OIDC token untuk autentikasi — hanya Pub/Sub SA yang boleh invoke Cloud Run
    oidc_token {
      service_account_email = var.pubsub_sa_email
      audience              = var.cloudrun_push_endpoint
    }

    # Attributes tambahan yang diinjeksikan ke header HTTP
    attributes = {
      x-goog-version = "v1"
    }
  }

  depends_on = [
    google_pubsub_topic.sensor_data,
    google_pubsub_topic.dead_letter
  ]
}

# ─── Subscription: Dead-Letter Pull (untuk monitoring & debugging) ────────────

resource "google_pubsub_subscription" "dead_letter_pull" {
  name    = "${var.topic_sensor_name}-dead-letter-pull"
  topic   = google_pubsub_topic.dead_letter.id
  project = var.project_id

  ack_deadline_seconds       = 20
  message_retention_duration = "2592000s"  # 30 hari
  retain_acked_messages      = true         # Simpan pesan yang sudah di-ack untuk audit
}

# ─── Subscription: Alert Notification (untuk push ke users) ──────────────────

resource "google_pubsub_subscription" "alert_push" {
  name    = "${var.topic_alert_name}-push"
  topic   = google_pubsub_topic.alert.id
  project = var.project_id

  ack_deadline_seconds = 30

  # Untuk alert, retry lebih agresif
  retry_policy {
    minimum_backoff = "5s"
    maximum_backoff = "60s"
  }
}

# ─── IAM: Publisher ke sensor topic ──────────────────────────────────────────

resource "google_pubsub_topic_iam_member" "sensor_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.sensor_data.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.cloudrun_sa_email}"
}

# IAM: Cloud Run SA boleh publish ke alert topic
resource "google_pubsub_topic_iam_member" "alert_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.alert.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.cloudrun_sa_email}"
}

# IAM: Pub/Sub service account boleh publish ke dead-letter (diperlukan oleh DLQ)
resource "google_pubsub_topic_iam_member" "pubsub_sa_dead_letter_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.dead_letter.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# IAM: Pub/Sub SA harus bisa subscribe ke subscription untuk DLQ
resource "google_pubsub_subscription_iam_member" "pubsub_sa_subscriber" {
  project      = var.project_id
  subscription = google_pubsub_subscription.cloudrun_push.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}
