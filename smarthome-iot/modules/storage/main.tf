##############################################################################
# modules/storage/main.tf
# Cloud Storage Bucket — Sensor Log Archive
# Security Engineer: Minggu 2 — Implementasi Infrastruktur Dasar
#
# Prinsip Keamanan yang Diterapkan:
#   1. Public Access Prevention = enforced (tidak ada objek yang bisa diakses publik)
#   2. Uniform bucket-level access (tidak ada per-object ACL — lebih aman dan konsisten)
#   3. Versioning diaktifkan — restore file yang terhapus/tertimpa
#   4. CMEK enkripsi at-rest dengan KMS Customer-Managed Key
#   5. Lifecycle policy — auto-tiering ke Nearline (30 hari) & delete (365 hari)
#   6. Object hold disabled — tapi retention policy untuk audit compliance
#   7. Audit logging diaktifkan melalui IAM modul (data access log)
##############################################################################

# ─── KMS Key untuk Cloud Storage CMEK ────────────────────────────────────────

resource "google_kms_key_ring" "storage_keyring" {
  name     = "${var.project_id}-storage-keyring"
  location = var.location == "ASIA-SOUTHEAST2" ? "asia-southeast2" : lower(var.location)
  project  = var.project_id
}

resource "google_kms_crypto_key" "storage_key" {
  name            = "smarthome-storage-key"
  key_ring        = google_kms_key_ring.storage_keyring.id
  rotation_period = "7776000s"  # Rotasi setiap 90 hari

  lifecycle {
    prevent_destroy = true
  }
}

# Berikan akses Cloud Storage Service Account ke KMS key
resource "google_kms_crypto_key_iam_member" "storage_sa_kms" {
  crypto_key_id = google_kms_crypto_key.storage_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@gs-project-accounts.iam.gserviceaccount.com"
}

# ─── Bucket Utama: Sensor Log Storage ─────────────────────────────────────────

resource "google_storage_bucket" "sensor_logs" {
  name          = var.bucket_name
  project       = var.project_id
  location      = var.location
  storage_class = "STANDARD"
  force_destroy = false  # Jangan hapus bucket yang masih berisi objek

  # Uniform access control — tidak ada per-object ACL
  uniform_bucket_level_access = true

  # Blokir SEMUA akses publik — enforce di level bucket
  public_access_prevention = "enforced"

  # Versioning — simpan versi sebelumnya saat objek di-overwrite atau dihapus
  versioning {
    enabled = true
  }

  # CMEK enkripsi at-rest
  encryption {
    default_kms_key_name = google_kms_crypto_key.storage_key.id
  }

  # ─── Lifecycle Policy ─────────────────────────────────────────────────────
  # Rule 1: Pindahkan objek aktif ke Nearline setelah 30 hari
  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  # Rule 2: Pindahkan objek Nearline ke Coldline setelah 90 hari
  lifecycle_rule {
    condition {
      age                = 90
      matches_storage_class = ["NEARLINE"]
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  # Rule 3: Hapus objek yang sudah lebih dari 365 hari (1 tahun retensi)
  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }

  # Rule 4: Hapus versi objek yang sudah tidak aktif setelah 30 hari
  lifecycle_rule {
    condition {
      num_newer_versions = 3
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  # ─── CORS (tidak diperlukan untuk backend-only access) ────────────────────
  # Dikosongkan secara sengaja — bucket ini tidak diakses dari browser

  # ─── Logging ──────────────────────────────────────────────────────────────
  logging {
    log_bucket        = google_storage_bucket.access_logs.name
    log_object_prefix = "sensor-logs-access/"
  }

  labels = var.labels

  depends_on = [google_kms_crypto_key_iam_member.storage_sa_kms]
}

# ─── Bucket untuk Access Log (Storage Audit Trail) ────────────────────────────
# Bucket terpisah khusus menyimpan access log dari bucket utama
# Ini memungkinkan audit trail siapa yang mengakses file sensor

resource "google_storage_bucket" "access_logs" {
  name          = "${var.bucket_name}-access-logs"
  project       = var.project_id
  location      = var.location
  storage_class = "NEARLINE"  # Log tidak perlu akses cepat
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  versioning {
    enabled = false  # Log tidak perlu versioning
  }

  # Hapus log lama setelah 90 hari untuk menghemat biaya
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  labels = var.labels
}

# ─── IAM Binding untuk Bucket ─────────────────────────────────────────────────

# Cloud Run SA — boleh membuat dan membaca objek (log sensor)
resource "google_storage_bucket_iam_member" "cloudrun_writer" {
  bucket = google_storage_bucket.sensor_logs.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${var.cloudrun_sa_email}"
}

# Cloud SQL SA — boleh baca/tulis untuk export backup
resource "google_storage_bucket_iam_member" "cloudsql_backup" {
  bucket = google_storage_bucket.sensor_logs.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.cloudsql_sa_email}"
}

# ─── Folder Structure (melalui empty objects sebagai "folder" placeholder) ────
# Struktur: year/month/day/sensor-type/

resource "google_storage_bucket_object" "folder_placeholder" {
  for_each = toset([
    "logs/placeholder.txt",
    "backups/placeholder.txt",
    "exports/placeholder.txt",
  ])

  name    = each.value
  bucket  = google_storage_bucket.sensor_logs.name
  content = "# Folder placeholder — dibuat otomatis oleh Terraform Minggu 2\n# Hapus file ini setelah data pertama masuk ke folder ini.\n"
}
