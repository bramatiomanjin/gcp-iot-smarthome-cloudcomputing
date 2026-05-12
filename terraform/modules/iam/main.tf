# Service Account: IoT Publisher
resource "google_service_account" "sa_iot_publisher" {
  account_id   = "sa-iot-publisher"
  display_name = "IoT Device Publisher"
  description  = "Digunakan oleh perangkat IoT untuk publish ke Pub/Sub"
  project      = var.project_id
}

resource "google_project_iam_member" "iot_publisher_role" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${google_service_account.sa_iot_publisher.email}"
}

# Service Account: Data Processor
resource "google_service_account" "sa_data_processor" {
  account_id   = "sa-data-processor"
  display_name = "Cloud Functions Processor"
  description  = "Digunakan oleh Cloud Functions untuk memproses data sensor"
  project      = var.project_id
}

locals {
  processor_roles = [
    "roles/pubsub.subscriber",
    "roles/datastore.user",
    "roles/storage.objectCreator",
    "roles/logging.logWriter",
  ]
}

resource "google_project_iam_member" "processor_roles" {
  for_each = toset(local.processor_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.sa_data_processor.email}"
}

# Service Account: Monitoring Agent
resource "google_service_account" "sa_monitoring_agent" {
  account_id   = "sa-monitoring-agent"
  display_name = "Monitoring and Logging Agent"
  description  = "Digunakan untuk Cloud Logging dan Cloud Monitoring"
  project      = var.project_id
}

locals {
  monitoring_roles = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ]
}

resource "google_project_iam_member" "monitoring_roles" {
  for_each = toset(local.monitoring_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.sa_monitoring_agent.email}"
}