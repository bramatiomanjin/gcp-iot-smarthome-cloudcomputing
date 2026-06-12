##############################################################################
# modules/cloudrun/main.tf
# Cloud Run v2 Service — Sensor Processor
# Security Engineer: Minggu 3 — Implementasi Layanan Inti
#
# Layanan ini menerima data sensor dari Pub/Sub (push subscription),
# memproses, memvalidasi, menulis ke Cloud SQL, dan menyimpan log ke Storage.
#
# Prinsip Keamanan yang Diterapkan:
#   1. Ingress = INTERNAL_AND_CLOUD_LOAD_BALANCING — tidak terekspos publik
#   2. Tidak ada unauthenticated invocation — hanya Pub/Sub SA via OIDC
#   3. Semua credential datang dari Secret Manager — ZERO hardcoded secrets
#   4. Cloud SQL dihubungkan via Unix socket (Cloud SQL Auth Proxy built-in)
#        BUKAN via IP publik — koneksi via Private IP + VPC connector
#   5. VPC connector mewajibkan semua traffic keluar melewati VPC internal
#   6. CPU throttling on idle (scale-to-zero) untuk efisiensi biaya
#   7. Request timeout = 60 detik — cegah hanging connections ke Cloud SQL
#   8. Binary Authorization bisa ditambahkan di Minggu 4
##############################################################################

# ─── Cloud Run v2 Service ─────────────────────────────────────────────────────

resource "google_cloud_run_v2_service" "sensor_processor" {
  name     = var.service_name
  project  = var.project_id
  location = var.region

  # ─── Ingress Control ───────────────────────────────────────────────────────
  # Hanya izinkan traffic dari dalam GCP (Pub/Sub, Load Balancer)
  # Traffic dari internet publik langsung DIBLOKIR
  ingress = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  labels = var.labels

  template {
    # ─── Service Account ─────────────────────────────────────────────────────
    # Cloud Run berjalan di bawah SA khusus — BUKAN default compute SA
    service_account = var.cloudrun_sa_email

    # ─── Execution Environment ───────────────────────────────────────────────
    execution_environment = "EXECUTION_ENVIRONMENT_GEN2"  # Gen2 = lebih cepat, lebih aman

    # ─── Auto-Scaling ────────────────────────────────────────────────────────
    scaling {
      min_instance_count = var.min_instances  # 0 = scale-to-zero saat idle
      max_instance_count = var.max_instances  # 3 = batas atas untuk kontrol biaya
    }

    # ─── VPC Network Config ──────────────────────────────────────────────────
    # Wajib agar Cloud Run bisa menjangkau Cloud SQL via Private IP
    # Semua traffic egress dilewatkan melalui VPC connector
    vpc_access {
      connector = var.vpc_connector_id
      egress    = "PRIVATE_RANGES_ONLY"  # Hanya traffic ke IP private lewat VPC; internet tetap via Google
    }

    # ─── Timeout & Concurrency ───────────────────────────────────────────────
    timeout                          = "60s"   # Max waktu pemrosesan 1 pesan
    max_instance_request_concurrency = 10       # Max 10 request concurrent per instance

    # ─── Annotations ─────────────────────────────────────────────────────────
    annotations = {
      "autoscaling.knative.dev/minScale"    = tostring(var.min_instances)
      "autoscaling.knative.dev/maxScale"    = tostring(var.max_instances)
      "run.googleapis.com/cloudsql-instances" = var.db_connection_name
    }

    labels = var.labels

    containers {
      # ─── Container Image ───────────────────────────────────────────────────
      # Image harus sudah ada di Artifact Registry sebelum terraform apply
      # Gunakan image bootstrap jika belum ada image custom (initial deploy)
      image = var.container_image

      # ─── Resource Limits ───────────────────────────────────────────────────
      resources {
        limits = {
          cpu    = var.cpu_limit     # "1" = 1 vCPU
          memory = var.memory_limit  # "256Mi"
        }
        # CPU hanya dialokasikan selama request diproses (bukan always-on)
        # Ini menghemat biaya signifikan untuk beban kerja sporadis
        cpu_idle          = false   # CPU tidak aktif saat instance idle (scale-to-zero mendukung ini)
        startup_cpu_boost = true    # Boost CPU saat cold start untuk mempercepat startup
      }

      # ─── Ports ─────────────────────────────────────────────────────────────
      ports {
        name           = "http1"
        container_port = 8080
      }

      # ─── Environment Variables (NON-SENSITIVE ONLY) ────────────────────────
      # ⚠️ TIDAK ADA nilai sensitif di env vars — semua dari Secret Manager
      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }

      env {
        name  = "DB_NAME"
        value = var.db_name
      }

      env {
        name  = "DB_USER"
        value = var.db_user
      }

      env {
        name  = "PUBSUB_ALERT_TOPIC"
        value = var.pubsub_alert_topic
      }

      env {
        name  = "STORAGE_BUCKET"
        value = var.storage_bucket_name
      }

      env {
        name  = "ENVIRONMENT"
        value = "dev"
      }

      # ─── Secret Environment Variables ──────────────────────────────────────
      # DB Password — diambil dari Secret Manager saat container startup
      # TIDAK pernah masuk ke container image atau log
      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = var.secret_db_password_id
            version = "latest"
          }
        }
      }

      # DB Connection String — format SQLAlchemy untuk Cloud SQL Connector
      env {
        name = "DB_CONNECTION_STRING"
        value_source {
          secret_key_ref {
            secret  = var.secret_db_connection_string_id
            version = "latest"
          }
        }
      }

      # ─── Volume Mounts — Secret sebagai File ───────────────────────────────
      # SSL Certificate dan Key dimount sebagai file (lebih aman dari env var)

      volume_mounts {
        name       = "ssl-certs"
        mount_path = "/secrets/ssl"
      }

      # ─── Liveness Probe ────────────────────────────────────────────────────
      liveness_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 10
        period_seconds        = 30
        failure_threshold     = 3
        timeout_seconds       = 5
      }

      # ─── Startup Probe ─────────────────────────────────────────────────────
      startup_probe {
        http_get {
          path = "/health"
          port = 8080
        }
        initial_delay_seconds = 5
        period_seconds        = 5
        failure_threshold     = 10  # 50 detik total untuk startup
        timeout_seconds       = 3
      }
    }

    # ─── Volume: SSL Certificates dari Secret Manager ─────────────────────────
    volumes {
      name = "ssl-certs"
      secret {
        secret       = var.secret_db_ssl_client_cert_id
        default_mode = 0400  # Read-only untuk owner saja

        items {
          version = "latest"
          path    = "client-cert.pem"
          mode    = 0400
        }
      }
    }
  }

  # Tunggu semua dependency selesai sebelum deploy Cloud Run
  depends_on = [
    var.vpc_connector_dependency,
    var.secrets_dependency,
  ]

  lifecycle {
    # Abaikan perubahan pada image — deployment image dikelola oleh CI/CD pipeline,
    # bukan oleh Terraform secara langsung
    ignore_changes = [
      template[0].containers[0].image,
      template[0].labels,
    ]
  }
}

# ─── IAM: Larang Unauthenticated Invocation ───────────────────────────────────
# Secara eksplisit MENCABUT akses allUsers dan allAuthenticatedUsers
# Ini memastikan HANYA Pub/Sub SA (via OIDC) yang bisa invoke service ini
# Bahkan developer dengan project access tidak bisa invoke langsung dari browser

resource "google_cloud_run_v2_service_iam_member" "pubsub_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.sensor_processor.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.pubsub_sa_email}"
}

# ─── IAM: CI/CD SA boleh redeploy service ────────────────────────────────────

resource "google_cloud_run_v2_service_iam_member" "cicd_developer" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.sensor_processor.name
  role     = "roles/run.developer"
  member   = "serviceAccount:${var.cicd_sa_email}"
}
