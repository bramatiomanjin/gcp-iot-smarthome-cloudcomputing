##############################################################################
# modules/storage/variables.tf
##############################################################################

variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "project_number" {
  description = "Google Cloud Project Number (untuk KMS IAM binding)"
  type        = string
}

variable "location" {
  description = "Lokasi bucket (GCS region)"
  type        = string
  default     = "ASIA-SOUTHEAST2"
}

variable "bucket_name" {
  description = "Nama bucket utama untuk sensor log"
  type        = string
}

variable "cloudrun_sa_email" {
  description = "Email service account Cloud Run (untuk IAM binding)"
  type        = string
}

variable "cloudsql_sa_email" {
  description = "Email service account Cloud SQL (untuk backup IAM binding)"
  type        = string
}

variable "labels" {
  description = "Label resource"
  type        = map(string)
  default     = {}
}
