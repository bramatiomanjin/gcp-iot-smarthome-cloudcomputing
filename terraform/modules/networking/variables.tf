##############################################################################
# modules/networking/variables.tf
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

variable "vpc_name" {
  description = "Nama VPC"
  type        = string
  default     = "smarthome-vpc"
}

variable "subnet_name" {
  description = "Nama subnet utama"
  type        = string
  default     = "smarthome-subnet"
}

variable "subnet_cidr" {
  description = "CIDR range subnet utama"
  type        = string
  default     = "10.0.1.0/24"
}

variable "labels" {
  description = "Label resource"
  type        = map(string)
  default     = {}
}
