##############################################################################
# modules/cloudrun/variables.tf
##############################################################################

variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "Region GCP"
  type        = string
  default     = "asia-southeast2"
}

variable "service_name" {
  description = "Nama Cloud Run service"
  type        = string
  default     = "sensor-processor"
}

variable "container_image" {
  description = "URL lengkap container image dari Artifact Registry"
  type        = string
  # Format: REGION-docker.pkg.dev/PROJECT_ID/REPO/IMAGE:TAG
}

variable "cloudrun_sa_email" {
  description = "Email Service Account yang digunakan Cloud Run untuk berjalan"
  type        = string
}

variable "pubsub_sa_email" {
  description = "Email Service Account Pub/Sub Invoker (yang boleh invoke Cloud Run)"
  type        = string
}

variable "cicd_sa_email" {
  description = "Email Service Account CI/CD (yang boleh redeploy Cloud Run)"
  type        = string
}

variable "vpc_connector_id" {
  description = "ID Serverless VPC Access Connector (format: projects/.../connectors/...)"
  type        = string
}

variable "db_connection_name" {
  description = "Connection name Cloud SQL (format: project:region:instance)"
  type        = string
}

variable "db_name" {
  description = "Nama database"
  type        = string
  default     = "smarthome"
}

variable "db_user" {
  description = "Username database"
  type        = string
  default     = "iot_user"
}

variable "pubsub_alert_topic" {
  description = "Nama topik Pub/Sub untuk publish alert"
  type        = string
  default     = "iot-alert-topic"
}

variable "storage_bucket_name" {
  description = "Nama bucket Cloud Storage untuk log sensor"
  type        = string
}

variable "secret_db_password_id" {
  description = "Secret ID untuk db-password di Secret Manager"
  type        = string
}

variable "secret_db_connection_string_id" {
  description = "Secret ID untuk db-connection-string di Secret Manager"
  type        = string
}

variable "secret_db_ssl_client_cert_id" {
  description = "Secret ID untuk db-ssl-client-cert di Secret Manager"
  type        = string
}

variable "min_instances" {
  description = "Minimum instance Cloud Run (0 = scale-to-zero)"
  type        = number
  default     = 0
}

variable "max_instances" {
  description = "Maximum instance Cloud Run"
  type        = number
  default     = 3
}

variable "cpu_limit" {
  description = "CPU limit per instance"
  type        = string
  default     = "1"
}

variable "memory_limit" {
  description = "Memory limit per instance"
  type        = string
  default     = "256Mi"
}

variable "vpc_connector_dependency" {
  description = "Dependency placeholder untuk VPC connector"
  type        = any
  default     = null
}

variable "secrets_dependency" {
  description = "Dependency placeholder untuk Secret Manager"
  type        = any
  default     = null
}

variable "labels" {
  description = "Label resource"
  type        = map(string)
  default     = {}
}
