##############################################################################
# modules/artifact_registry/variables.tf
##############################################################################

variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "project_number" {
  description = "Google Cloud Project Number (untuk Cloud Build SA)"
  type        = string
}

variable "region" {
  description = "Region untuk Artifact Registry (harus sama dengan Cloud Run)"
  type        = string
  default     = "asia-southeast2"
}

variable "repository_id" {
  description = "ID repository Artifact Registry"
  type        = string
  default     = "smarthome-registry"
}

variable "cloudrun_sa_email" {
  description = "Email SA Cloud Run (untuk pull image)"
  type        = string
}

variable "cicd_sa_email" {
  description = "Email SA CI/CD (untuk push image)"
  type        = string
}

variable "api_dependency" {
  description = "Dependency placeholder untuk google_project_service"
  type        = any
  default     = null
}

variable "labels" {
  description = "Label resource"
  type        = map(string)
  default     = {}
}
