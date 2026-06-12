##############################################################################
# terraform.tfvars  —  Minggu 5 FINAL (v1.0.0)
# Real-Time IoT Smart Home Monitoring & Alert System
# Security Engineer: Haryadi Yusuf (2330305030074)
# ⚠️  File ini di-gitignore. Jangan commit ke repository publik.
##############################################################################

project_id  = "cloud-computing-495107"
region      = "asia-southeast2"
zone        = "asia-southeast2-a"
environment = "dev"

# ─── Networking ───────────────────────────────────────────────────────────────
vpc_name    = "smarthome-vpc"
subnet_name = "smarthome-subnet"
subnet_cidr = "10.0.1.0/24"

# ─── Cloud SQL ────────────────────────────────────────────────────────────────
db_instance_name = "iot-db"
db_name          = "smarthome"
db_tier          = "db-f1-micro"
db_user          = "iot_user"

# ─── Cloud Storage ────────────────────────────────────────────────────────────
storage_bucket_name = "smarthome-sensor-logs-cloud-computing-495107"
storage_location    = "ASIA-SOUTHEAST2"

# ─── Pub/Sub ──────────────────────────────────────────────────────────────────
pubsub_topic_sensor = "iot-topic"
pubsub_topic_alert  = "iot-alert-topic"

# ─── Artifact Registry ────────────────────────────────────────────────────────
artifact_registry_repo_id = "smarthome-registry"

# ─── Cloud Run ────────────────────────────────────────────────────────────────
cloudrun_service_name  = "sensor-processor"
cloudrun_image_name    = "sensor-processor"
cloudrun_image_tag     = "v1.0.0"
cloudrun_min_instances = 0
cloudrun_max_instances = 3
cloudrun_cpu_limit     = "1"
cloudrun_memory_limit  = "256Mi"

# ─── Monitoring & Alert ───────────────────────────────────────────────────────
alert_email = "your-email@students.upr.ac.id"

# ─── Labels — versi final ─────────────────────────────────────────────────────
labels = {
  project     = "smarthome-iot"
  team        = "informatika-upr"
  environment = "dev"
  managed_by  = "terraform"
  minggu      = "5"
  version     = "v1-0-0"
}

# ─── Billing ──────────────────────────────────────────────────────────────────
billing_account_id = ""  # Isi dengan: gcloud billing accounts list
