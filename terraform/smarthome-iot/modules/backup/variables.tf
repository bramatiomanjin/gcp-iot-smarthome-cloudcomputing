##############################################################################
# modules/backup/variables.tf
##############################################################################

variable "project_id" { type = string }
variable "project_number" { type = string }
variable "region" {
  type    = string
  default = "asia-southeast2"
}

variable "db_instance_name" {
  description = "Nama instance Cloud SQL untuk di-backup"
  type        = string
  default     = "iot-db"
}

variable "db_name" {
  description = "Nama database yang di-export"
  type        = string
  default     = "smarthome"
}

variable "cloudsql_sa_email" {
  description = "Email service account Cloud SQL"
  type        = string
}

variable "notification_channel_name" {
  description = "Nama notification channel dari module monitoring"
  type        = string
}

variable "kms_key_id" {
  description = "KMS key ID untuk enkripsi backup bucket (opsional)"
  type        = string
  default     = ""
}

variable "labels" {
  type    = map(string)
  default = {}
}
