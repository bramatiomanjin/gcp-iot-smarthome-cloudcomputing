##############################################################################
# main.tf  —  Root Module  |  VERSI FINAL v1.0.0  (Minggu 5)
# Real-Time IoT Smart Home Monitoring & Alert System — GCP
# Universitas Palangka Raya | Cloud Computing Final Project 2026
#
# Security Engineer & Terraform Lead: Haryadi Yusuf (2330305030074)
#
# ═══════════════════════════════════════════════════════════════════════════
# RINGKASAN MODUL (11 modul, 9 resource types)
# ═══════════════════════════════════════════════════════════════════════════
#  Minggu 1  │ networking        VPC, Subnet, Firewall, VPC Connector
#             │ iam               Service Accounts, IAM Bindings (least priv)
#  ───────────┼─────────────────────────────────────────────────────────────
#  Minggu 2  │ database          Cloud SQL MySQL 8.0 (Private IP, CMEK, mTLS)
#             │ storage           Cloud Storage (CMEK, versioning, lifecycle)
#             │ secrets           Secret Manager (DB creds, SSL certs)
#             │ pubsub            Pub/Sub topics & subscriptions
#  ───────────┼─────────────────────────────────────────────────────────────
#  Minggu 3  │ artifact_registry Artifact Registry (Docker, private, scan)
#             │ cloudrun          Cloud Run sensor-processor (Gen2, serverless)
#  ───────────┼─────────────────────────────────────────────────────────────
#  Minggu 4  │ monitoring        Dashboard, 7 alert policies, log sinks
#             │ backup            Cloud Scheduler daily/weekly export
#             │ security          SCC, Org Policies, Binary Auth, IAM alerts
#  ───────────┼─────────────────────────────────────────────────────────────
#  Minggu 5  │ Cleanup, finalisasi tag, dokumentasi, CHANGELOG
# ═══════════════════════════════════════════════════════════════════════════
##############################################################################

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.4"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ─── Enable APIs ─────────────────────────────────────────────────────────────

locals {
  required_apis = [
    "compute.googleapis.com",
    "sqladmin.googleapis.com",
    "run.googleapis.com",
    "cloudfunctions.googleapis.com",
    "pubsub.googleapis.com",
    "storage.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "vpcaccess.googleapis.com",
    "cloudkms.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudscheduler.googleapis.com",
    "cloudbuild.googleapis.com",
    "containerscanning.googleapis.com",
    "binaryauthorization.googleapis.com",
    "containeranalysis.googleapis.com",
    "securitycenter.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each                   = toset(local.required_apis)
  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

data "google_project" "project" {
  project_id = var.project_id
}

# ─── Module: Networking ───────────────────────────────────────────────────────

module "networking" {
  source = "./modules/networking"

  project_id  = var.project_id
  region      = var.region
  vpc_name    = var.vpc_name
  subnet_name = var.subnet_name
  subnet_cidr = var.subnet_cidr
  labels      = var.labels

  depends_on = [google_project_service.apis]
}

# ─── Module: IAM ─────────────────────────────────────────────────────────────

module "iam" {
  source = "./modules/iam"

  project_id = var.project_id
  labels     = var.labels

  depends_on = [google_project_service.apis]
}

# ─── Module: Artifact Registry ───────────────────────────────────────────────

module "artifact_registry" {
  source = "./modules/artifact_registry"

  project_id     = var.project_id
  project_number = data.google_project.project.number
  region         = var.region
  repository_id  = var.artifact_registry_repo_id

  cloudrun_sa_email = module.iam.cloudrun_sa_email
  cicd_sa_email     = module.iam.cicd_sa_email
  api_dependency    = google_project_service.apis
  labels            = var.labels

  depends_on = [module.iam, google_project_service.apis]
}

# ─── Module: Database ────────────────────────────────────────────────────────

module "database" {
  source = "./modules/database"

  project_id     = var.project_id
  project_number = data.google_project.project.number
  region         = var.region

  db_instance_name          = var.db_instance_name
  db_name                   = var.db_name
  db_tier                   = var.db_tier
  db_user                   = var.db_user
  vpc_id                    = module.networking.vpc_id
  private_vpc_connection_id = module.networking.private_service_range_name
  labels                    = var.labels

  depends_on = [module.networking, google_project_service.apis]
}

# ─── Module: Storage ─────────────────────────────────────────────────────────

module "storage" {
  source = "./modules/storage"

  project_id        = var.project_id
  project_number    = data.google_project.project.number
  location          = var.storage_location
  bucket_name       = var.storage_bucket_name != "" ? var.storage_bucket_name : "smarthome-sensor-logs-${var.project_id}"
  cloudrun_sa_email = module.iam.cloudrun_sa_email
  cloudsql_sa_email = module.iam.cloudsql_sa_email
  labels            = var.labels

  depends_on = [module.iam, google_project_service.apis]
}

# ─── Module: Secrets ─────────────────────────────────────────────────────────

module "secrets" {
  source = "./modules/secrets"

  project_id                  = var.project_id
  region                      = var.region
  db_password                 = module.database.db_password
  db_user                     = var.db_user
  db_name                     = var.db_name
  db_instance_connection_name = module.database.instance_connection_name
  db_ssl_client_cert          = module.database.ssl_client_cert
  db_ssl_client_key           = module.database.ssl_client_key
  db_server_ca                = module.database.ssl_cert_server_ca
  cloudrun_sa_email           = module.iam.cloudrun_sa_email
  cicd_sa_email               = module.iam.cicd_sa_email
  labels                      = var.labels

  depends_on = [module.database, module.iam, google_project_service.apis]
}

# ─── Module: Cloud Run ───────────────────────────────────────────────────────

module "cloudrun" {
  source = "./modules/cloudrun"

  project_id    = var.project_id
  region        = var.region
  service_name  = var.cloudrun_service_name
  container_image = "${module.artifact_registry.image_base_url}/${var.cloudrun_image_name}:${var.cloudrun_image_tag}"

  cloudrun_sa_email  = module.iam.cloudrun_sa_email
  pubsub_sa_email    = module.iam.pubsub_sa_email
  cicd_sa_email      = module.iam.cicd_sa_email
  vpc_connector_id   = module.networking.vpc_connector_id

  db_connection_name  = module.database.instance_connection_name
  db_name             = var.db_name
  db_user             = var.db_user
  pubsub_alert_topic  = var.pubsub_topic_alert
  storage_bucket_name = module.storage.bucket_name

  secret_db_password_id          = module.secrets.db_password_secret_id
  secret_db_connection_string_id = module.secrets.db_connection_string_secret_id
  secret_db_ssl_client_cert_id   = module.secrets.db_ssl_client_cert_secret_id

  min_instances = var.cloudrun_min_instances
  max_instances = var.cloudrun_max_instances
  cpu_limit     = var.cloudrun_cpu_limit
  memory_limit  = var.cloudrun_memory_limit

  vpc_connector_dependency = module.networking.vpc_connector_id
  secrets_dependency       = module.secrets.db_password_secret_id
  labels                   = var.labels

  depends_on = [
    module.networking, module.iam, module.database,
    module.storage, module.secrets, module.artifact_registry,
    google_project_service.apis,
  ]
}

# ─── Module: Pub/Sub ─────────────────────────────────────────────────────────

module "pubsub" {
  source = "./modules/pubsub"

  project_id            = var.project_id
  project_number        = data.google_project.project.number
  topic_sensor_name     = var.pubsub_topic_sensor
  topic_alert_name      = var.pubsub_topic_alert
  cloudrun_push_endpoint = module.cloudrun.service_url
  cloudrun_sa_email     = module.iam.cloudrun_sa_email
  pubsub_sa_email       = module.iam.pubsub_sa_email
  labels                = var.labels

  depends_on = [module.iam, module.cloudrun, google_project_service.apis]
}

# ─── Module: Monitoring ──────────────────────────────────────────────────────

module "monitoring" {
  source = "./modules/monitoring"

  project_id            = var.project_id
  region                = var.region
  alert_email           = var.alert_email
  cloudrun_service_name = var.cloudrun_service_name
  db_instance_name      = var.db_instance_name
  log_bucket_name       = module.storage.bucket_name
  cloudrun_service_host = replace(module.cloudrun.service_url, "https://", "")
  billing_account_id    = var.billing_account_id
  project_number        = data.google_project.project.number
  labels                = var.labels

  depends_on = [module.cloudrun, module.database, module.storage, google_project_service.apis]
}

# ─── Module: Backup ──────────────────────────────────────────────────────────

module "backup" {
  source = "./modules/backup"

  project_id                = var.project_id
  project_number            = data.google_project.project.number
  region                    = var.region
  db_instance_name          = var.db_instance_name
  db_name                   = var.db_name
  cloudsql_sa_email         = module.iam.cloudsql_sa_email
  notification_channel_name = module.monitoring.notification_channel_name
  labels                    = var.labels

  depends_on = [module.database, module.monitoring, google_project_service.apis]
}

# ─── Module: Security ────────────────────────────────────────────────────────

module "security" {
  source = "./modules/security"

  project_id                = var.project_id
  region                    = var.region
  notification_channel_name = module.monitoring.notification_channel_name
  labels                    = var.labels

  depends_on = [module.monitoring, google_project_service.apis]
}
