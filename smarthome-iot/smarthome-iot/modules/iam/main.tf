##############################################################################
# modules/iam/main.tf
# Identity & Access Management — Service Accounts, Role Bindings
# Prinsip: Least Privilege — setiap service account HANYA mendapat role
# yang benar-benar diperlukan, tidak lebih.
##############################################################################

# ─── Service Account: Cloud Run (Sensor Processor) ───────────────────────────
# Menjalankan logika pemrosesan data sensor, menulis ke Cloud SQL & Storage

resource "google_service_account" "cloudrun_sa" {
  account_id   = "sa-cloudrun-processor"
  display_name = "Cloud Run Sensor Processor SA"
  description  = "Service account untuk Cloud Run yang memproses data sensor IoT"
  project      = var.project_id
}

# Cloud Run SA — akses Cloud SQL (hanya connect, bukan admin)
resource "google_project_iam_member" "cloudrun_cloudsql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# Cloud Run SA — baca secret dari Secret Manager (DB password, dll)
resource "google_project_iam_member" "cloudrun_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# Cloud Run SA — tulis ke Cloud Storage (log sensor)
resource "google_project_iam_member" "cloudrun_storage_writer" {
  project = var.project_id
  role    = "roles/storage.objectCreator"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# Cloud Run SA — publish ke Pub/Sub alert topic
resource "google_project_iam_member" "cloudrun_pubsub_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# Cloud Run SA — tulis log ke Cloud Logging
resource "google_project_iam_member" "cloudrun_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# Cloud Run SA — tulis metrik ke Cloud Monitoring
resource "google_project_iam_member" "cloudrun_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.cloudrun_sa.email}"
}

# ─── Service Account: Pub/Sub Invoker ────────────────────────────────────────
# Digunakan oleh Pub/Sub untuk men-trigger (invoke) Cloud Run via push subscription

resource "google_service_account" "pubsub_sa" {
  account_id   = "sa-pubsub-invoker"
  display_name = "Pub/Sub Cloud Run Invoker SA"
  description  = "Service account untuk Pub/Sub push subscription agar dapat invoke Cloud Run"
  project      = var.project_id
}

# Pub/Sub SA — hanya boleh invoke Cloud Run, tidak lebih
resource "google_project_iam_member" "pubsub_cloudrun_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.pubsub_sa.email}"
}

# ─── Service Account: Cloud SQL ──────────────────────────────────────────────
# Digunakan oleh instance Cloud SQL untuk operasi backup, export, dll.

resource "google_service_account" "cloudsql_sa" {
  account_id   = "sa-cloudsql"
  display_name = "Cloud SQL Service SA"
  description  = "Service account untuk operasi Cloud SQL (backup, export)"
  project      = var.project_id
}

# Cloud SQL SA — akses bucket untuk backup export
resource "google_project_iam_member" "cloudsql_storage_admin" {
  project = var.project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.cloudsql_sa.email}"
}

# ─── Service Account: Monitoring & Alerting ──────────────────────────────────

resource "google_service_account" "monitoring_sa" {
  account_id   = "sa-monitoring"
  display_name = "Monitoring & Alerting SA"
  description  = "Service account untuk Cloud Monitoring dan Cloud Logging"
  project      = var.project_id
}

# Monitoring SA — baca metrik dan log
resource "google_project_iam_member" "monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.monitoring_sa.email}"
}

resource "google_project_iam_member" "monitoring_log_viewer" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${google_service_account.monitoring_sa.email}"
}

# ─── Service Account: CI/CD (GitHub Actions / Cloud Build) ───────────────────
# SA khusus untuk pipeline deployment — scope sangat terbatas

resource "google_service_account" "cicd_sa" {
  account_id   = "sa-cicd-deploy"
  display_name = "CI/CD Deployment SA"
  description  = "Service account untuk GitHub Actions / Cloud Build deployment pipeline"
  project      = var.project_id
}

# CI/CD SA — deploy Cloud Run
resource "google_project_iam_member" "cicd_cloudrun_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

# CI/CD SA — push image ke Artifact Registry
resource "google_project_iam_member" "cicd_artifact_writer" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

# CI/CD SA — baca secret (untuk inject ke deployment)
resource "google_project_iam_member" "cicd_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cicd_sa.email}"
}

# ─── Audit Logging ───────────────────────────────────────────────────────────
# Aktifkan data access audit log untuk semua layanan kritis
# Ini penting untuk compliance dan forensic jika terjadi insiden keamanan

resource "google_project_iam_audit_config" "all_services_audit" {
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
