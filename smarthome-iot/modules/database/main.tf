##############################################################################
# modules/database/main.tf
# Cloud SQL MySQL 8.0 — Private IP, Automated Backup, CMEK Encryption
# Security Engineer: Minggu 2 — Implementasi Infrastruktur Dasar
#
# Prinsip Keamanan yang Diterapkan:
#   1. Private IP ONLY — tidak ada IP publik yang terekspos ke internet
#   2. Enkripsi at-rest menggunakan Customer-Managed Encryption Key (CMEK)
#   3. Automated backup harian dengan retensi 7 hari
#   4. SSL/TLS required untuk semua koneksi ke database
#   5. Password disimpan di Secret Manager, BUKAN di environment variable
#   6. Database flags untuk hardening: skip-show-database, local-infile=off
##############################################################################

# ─── KMS Key Ring & Crypto Key untuk CMEK ────────────────────────────────────
# Customer-Managed Encryption Key memastikan kita (bukan Google) yang
# mengontrol kunci enkripsi data di Cloud SQL

resource "google_kms_key_ring" "sql_keyring" {
  name     = "${var.project_id}-sql-keyring"
  location = var.region
  project  = var.project_id
}

resource "google_kms_crypto_key" "sql_key" {
  name            = "smarthome-sql-key"
  key_ring        = google_kms_key_ring.sql_keyring.id
  rotation_period = "7776000s"  # Rotasi otomatis setiap 90 hari

  lifecycle {
    prevent_destroy = true  # Jangan hapus kunci meski resource di-destroy
  }
}

# Berikan akses Cloud SQL Service Account ke KMS key
resource "google_kms_crypto_key_iam_member" "sql_sa_kms" {
  crypto_key_id = google_kms_crypto_key.sql_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@gcp-sa-cloud-sql.iam.gserviceaccount.com"
}

# ─── Cloud SQL Instance ───────────────────────────────────────────────────────

resource "google_sql_database_instance" "main" {
  name             = var.db_instance_name
  project          = var.project_id
  database_version = "MYSQL_8_0"
  region           = var.region

  # CMEK — enkripsi at-rest dengan kunci yang kita kontrol
  encryption_key_name = google_kms_crypto_key.sql_key.id

  # Dependensi: peering VPC harus selesai dulu agar Private IP bisa dikonfigurasi
  depends_on = [var.private_vpc_connection_id]

  settings {
    tier              = var.db_tier
    availability_type = "ZONAL"  # Single zone untuk dev; gunakan REGIONAL untuk prod

    # ─── IP Configuration: Private IP ONLY ───────────────────────────────────
    ip_configuration {
      ipv4_enabled                                  = false  # MATIKAN IP publik
      private_network                               = var.vpc_id
      enable_private_path_for_google_cloud_services = true

      # SSL/TLS wajib untuk semua koneksi
      ssl_mode = "TRUSTED_CLIENT_CERTIFICATE_REQUIRED"

      # Authorized networks kosong — karena kita pakai Private IP
      # Tidak ada akses dari IP publik sama sekali
    }

    # ─── Backup & Recovery ────────────────────────────────────────────────────
    backup_configuration {
      enabled                        = true
      binary_log_enabled             = true   # Diperlukan untuk point-in-time recovery
      start_time                     = "02:00" # Backup pukul 02:00 WIB
      transaction_log_retention_days = 7
      location                       = var.region

      backup_retention_settings {
        retained_backups = 7    # Simpan 7 backup (1 minggu)
        retention_unit   = "COUNT"
      }
    }

    # ─── Maintenance Window ───────────────────────────────────────────────────
    maintenance_window {
      day          = 7    # Minggu
      hour         = 3    # Pukul 03:00 WIB
      update_track = "stable"
    }

    # ─── Storage ─────────────────────────────────────────────────────────────
    disk_autoresize       = true
    disk_autoresize_limit = 20   # Maksimum 20 GB auto-resize
    disk_size             = 10
    disk_type             = "PD_SSD"

    # ─── Database Flags (Security Hardening) ─────────────────────────────────
    # Referensi: CIS Google Cloud Benchmark — Database section
    database_flags {
      name  = "skip_show_database"
      value = "on"
    }

    database_flags {
      name  = "local_infile"
      value = "off"  # Mencegah serangan local file read
    }

    database_flags {
      name  = "general_log"
      value = "off"  # Nonaktifkan general log (menghemat storage dan I/O)
    }

    database_flags {
      name  = "slow_query_log"
      value = "on"   # Aktifkan slow query log untuk debugging performa
    }

    database_flags {
      name  = "long_query_time"
      value = "2"    # Query > 2 detik dianggap lambat
    }

    # ─── Query Insights ───────────────────────────────────────────────────────
    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false  # Privasi: jangan log IP klien
    }

    # ─── Labels ───────────────────────────────────────────────────────────────
    user_labels = var.labels
  }

  # Lindungi instance dari penghapusan tidak sengaja via terraform destroy
  deletion_protection = false  # Set true untuk production
}

# ─── Database ─────────────────────────────────────────────────────────────────

resource "google_sql_database" "smarthome" {
  name      = var.db_name
  instance  = google_sql_database_instance.main.name
  project   = var.project_id
  charset   = "utf8mb4"
  collation = "utf8mb4_unicode_ci"
}

# ─── Database User ────────────────────────────────────────────────────────────
# Password di-generate secara random dan disimpan ke Secret Manager
# TIDAK ADA password yang di-hardcode di sini

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_sql_user" "iot_user" {
  name     = var.db_user
  instance = google_sql_database_instance.main.name
  project  = var.project_id
  password = random_password.db_password.result

  # Batasi akses hanya dari IP internal (Private IP Cloud SQL tidak butuh host restriction,
  # tapi ini sebagai dokumentasi intent)
  host = "%"
}

# ─── SSL Certificate untuk Client Authentication ──────────────────────────────
# Sertifikat klien digunakan Cloud Run untuk autentikasi ke Cloud SQL via SSL

resource "google_sql_ssl_cert" "cloudrun_cert" {
  common_name = "cloudrun-client-cert"
  instance    = google_sql_database_instance.main.name
  project     = var.project_id
}
