##############################################################################
# variables.tf
# Semua variabel input untuk infrastruktur Smart Home IoT GCP
# Update Minggu 3: tambahan variabel untuk Artifact Registry dan Cloud Run
##############################################################################

# ─── Project & Region ────────────────────────────────────────────────────────

variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Region GCP utama (Jakarta)"
  type        = string
  default     = "asia-southeast2"
}

variable "zone" {
  description = "Zone GCP utama"
  type        = string
  default     = "asia-southeast2-a"
}

variable "environment" {
  description = "Environment label (dev / staging / prod)"
  type        = string
  default     = "dev"
}

# ─── Networking ──────────────────────────────────────────────────────────────

variable "vpc_name" {
  description = "Nama VPC utama proyek"
  type        = string
  default     = "smarthome-vpc"
}

variable "subnet_name" {
  description = "Nama subnet utama"
  type        = string
  default     = "smarthome-subnet"
}

variable "subnet_cidr" {
  description = "CIDR range subnet utama"
  type        = string
  default     = "10.0.1.0/24"
}

# ─── Cloud SQL ───────────────────────────────────────────────────────────────

variable "db_instance_name" {
  description = "Nama instance Cloud SQL"
  type        = string
  default     = "iot-db"
}

variable "db_name" {
  description = "Nama database di dalam instance Cloud SQL"
  type        = string
  default     = "smarthome"
}

variable "db_tier" {
  description = "Tier/machine type instance Cloud SQL"
  type        = string
  default     = "db-f1-micro"
}

variable "db_user" {
  description = "Username database utama"
  type        = string
  default     = "iot_user"
}

# ─── Cloud Storage ───────────────────────────────────────────────────────────

variable "storage_bucket_name" {
  description = "Nama bucket Cloud Storage (harus unik global; kosongkan untuk auto-generate)"
  type        = string
  default     = ""
}

variable "storage_location" {
  description = "Lokasi bucket Cloud Storage"
  type        = string
  default     = "ASIA-SOUTHEAST2"
}

# ─── Pub/Sub ─────────────────────────────────────────────────────────────────

variable "pubsub_topic_sensor" {
  description = "Nama topik Pub/Sub untuk data sensor"
  type        = string
  default     = "iot-topic"
}

variable "pubsub_topic_alert" {
  description = "Nama topik Pub/Sub untuk alert"
  type        = string
  default     = "iot-alert-topic"
}

# ─── Artifact Registry (BARU — Minggu 3) ─────────────────────────────────────

variable "artifact_registry_repo_id" {
  description = "ID repository Artifact Registry untuk container image"
  type        = string
  default     = "smarthome-registry"
}

# ─── Cloud Run (Diperluas — Minggu 3) ────────────────────────────────────────

variable "cloudrun_service_name" {
  description = "Nama layanan Cloud Run pemrosesan sensor"
  type        = string
  default     = "sensor-processor"
}

variable "cloudrun_image_name" {
  description = "Nama image container (tanpa tag)"
  type        = string
  default     = "sensor-processor"
}

variable "cloudrun_image_tag" {
  description = "Tag image container yang di-deploy"
  type        = string
  default     = "latest"
}

variable "cloudrun_min_instances" {
  description = "Minimum instance Cloud Run (0 = scale-to-zero)"
  type        = number
  default     = 0
}

variable "cloudrun_max_instances" {
  description = "Maximum instance Cloud Run"
  type        = number
  default     = 3
}

variable "cloudrun_cpu_limit" {
  description = "CPU limit per instance Cloud Run"
  type        = string
  default     = "1"
}

variable "cloudrun_memory_limit" {
  description = "Memory limit per instance Cloud Run"
  type        = string
  default     = "256Mi"
}

# ─── Monitoring & Alerting ───────────────────────────────────────────────────

variable "alert_email" {
  description = "Email penerima notifikasi alert Cloud Monitoring"
  type        = string
  default     = ""
}

# ─── Labels ──────────────────────────────────────────────────────────────────

variable "labels" {
  description = "Label/tag yang diterapkan ke semua resource"
  type        = map(string)
  default = {
    project     = "smarthome-iot"
    team        = "informatika-upr"
    environment = "dev"
    managed_by  = "terraform"
  }
}

variable "billing_account_id" {
  description = "ID billing account GCP (contoh: XXXXXX-XXXXXX-XXXXXX)"
  type        = string
  default     = ""
}
