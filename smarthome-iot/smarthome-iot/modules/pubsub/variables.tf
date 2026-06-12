##############################################################################
# modules/pubsub/variables.tf
##############################################################################

variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "project_number" {
  description = "Google Cloud Project Number"
  type        = string
}

variable "topic_sensor_name" {
  description = "Nama topik Pub/Sub untuk data sensor"
  type        = string
  default     = "iot-topic"
}

variable "topic_alert_name" {
  description = "Nama topik Pub/Sub untuk alert"
  type        = string
  default     = "iot-alert-topic"
}

variable "cloudrun_push_endpoint" {
  description = "URL endpoint Cloud Run untuk push subscription"
  type        = string
  default     = "https://placeholder.run.app"  # Diupdate setelah Cloud Run deploy
}

variable "cloudrun_sa_email" {
  description = "Email service account Cloud Run"
  type        = string
}

variable "pubsub_sa_email" {
  description = "Email service account Pub/Sub invoker"
  type        = string
}

variable "labels" {
  description = "Label resource"
  type        = map(string)
  default     = {}
}
