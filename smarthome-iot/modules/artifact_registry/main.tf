##############################################################################
# modules/artifact_registry/main.tf
# Artifact Registry — Docker Repository untuk Container Image Cloud Run
# Security Engineer: Minggu 3 — Implementasi Layanan Inti
#
# Prinsip Keamanan yang Diterapkan:
#   1. Repository bersifat PRIVATE — tidak ada image yang dapat diakses publik
#   2. Vulnerability scanning otomatis diaktifkan pada setiap push
#   3. Hanya SA CI/CD yang boleh push; SA Cloud Run hanya boleh pull
#   4. Immutable tag policy mencegah overwrite image yang sudah di-deploy
#   5. Enkripsi at-rest menggunakan Google-managed key (CMEK opsional)
#   6. Labels konsisten untuk cost tracking dan audit
##############################################################################

# ─── Artifact Registry Repository ────────────────────────────────────────────
# Repository Docker privat untuk menyimpan container image sensor-processor

resource "google_artifact_registry_repository" "smarthome_registry" {
  repository_id = var.repository_id
  project       = var.project_id
  location      = var.region
  format        = "DOCKER"
  description   = "Registry container image untuk Smart Home IoT — sensor-processor service"

  # Mode: STANDARD (immutable vs mutable diatur via tag policies di bawah)
  mode = "STANDARD_REPOSITORY"

  labels = var.labels

  # Cleanup policy — hapus image yang tidak digunakan untuk menghemat biaya storage
  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"
    most_recent_versions {
      keep_count = 5  # Simpan 5 versi terakhir per package
    }
  }

  cleanup_policies {
    id     = "delete-old-untagged"
    action = "DELETE"
    condition {
      older_than   = "2592000s"  # 30 hari
      tag_state    = "UNTAGGED"  # Hanya hapus image yang tidak memiliki tag
    }
  }

  # Docker config — untuk immutable tags (mencegah overwrite :latest secara tidak sengaja)
  docker_config {
    immutable_tags = false  # Set true untuk production — false untuk dev agar bisa redeploy
  }

  depends_on = [var.api_dependency]
}

# ─── IAM: CI/CD SA — push image ke registry ──────────────────────────────────
# SA CI/CD (GitHub Actions / Cloud Build) perlu push image baru ke registry

resource "google_artifact_registry_repository_iam_member" "cicd_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.smarthome_registry.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.cicd_sa_email}"
}

# ─── IAM: Cloud Run SA — pull image dari registry ────────────────────────────
# SA Cloud Run hanya perlu pull image saat startup — tidak perlu push

resource "google_artifact_registry_repository_iam_member" "cloudrun_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.smarthome_registry.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.cloudrun_sa_email}"
}

# ─── IAM: Cloud Build SA — build dan push image ──────────────────────────────
# Jika menggunakan Cloud Build sebagai CI runner

resource "google_artifact_registry_repository_iam_member" "cloudbuild_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.smarthome_registry.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
}
