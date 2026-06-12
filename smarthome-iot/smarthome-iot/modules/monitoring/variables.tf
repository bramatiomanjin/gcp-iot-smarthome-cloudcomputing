##############################################################################
# modules/monitoring/variables.tf
##############################################################################

variable "project_id" {
  type = string
}

variable "region" {
  type    = string
  default = "asia-southeast2"
}

variable "alert_email" {
  description = "Email penerima notifikasi alert"
  type        = string
}

variable "cloudrun_service_name" {
  description = "Nama Cloud Run service yang dimonitor"
  type        = string
  default     = "sensor-processor"
}

variable "cloudrun_service_host" {
  description = "Domain host Cloud Run tanpa https:// (dari output module cloudrun)"
  type        = string
}

variable "db_instance_name" {
  description = "Nama instance Cloud SQL yang dimonitor"
  type        = string
  default     = "iot-db"
}

variable "log_bucket_name" {
  description = "Nama bucket Cloud Storage untuk log sink"
  type        = string
}

variable "labels" {
  type    = map(string)
  default = {}
}

variable "billing_account_id" {
  description = "ID akun billing GCP (untuk budget alert)"
  type        = string
  default     = ""
}

variable "project_number" {
  description = "GCP project number (untuk budget filter)"
  type        = string
  default     = ""
}
