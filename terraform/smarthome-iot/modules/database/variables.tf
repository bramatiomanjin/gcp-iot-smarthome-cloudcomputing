##############################################################################
# modules/database/variables.tf
##############################################################################

variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "project_number" {
  description = "Google Cloud Project Number (untuk KMS IAM binding)"
  type        = string
}

variable "region" {
  description = "Region GCP"
  type        = string
  default     = "asia-southeast2"
}

variable "db_instance_name" {
  description = "Nama instance Cloud SQL"
  type        = string
  default     = "iot-db"
}

variable "db_name" {
  description = "Nama database"
  type        = string
  default     = "smarthome"
}

variable "db_tier" {
  description = "Machine tier Cloud SQL"
  type        = string
  default     = "db-f1-micro"
}

variable "db_user" {
  description = "Username database"
  type        = string
  default     = "iot_user"
}

variable "vpc_id" {
  description = "Self-link VPC untuk Private IP Cloud SQL"
  type        = string
}

variable "private_vpc_connection_id" {
  description = "ID private VPC connection (untuk depends_on)"
  type        = string
}

variable "labels" {
  description = "Label resource"
  type        = map(string)
  default     = {}
}
