##############################################################################
# modules/security/variables.tf
##############################################################################

variable "project_id" { type = string }
variable "region" {
  type    = string
  default = "asia-southeast2"
}

variable "org_id" {
  description = "GCP Organization ID (kosongkan jika tidak ada org, gunakan folder_id)"
  type        = string
  default     = ""
}

variable "notification_channel_name" {
  description = "Nama notification channel dari module monitoring"
  type        = string
}

variable "labels" {
  type    = map(string)
  default = {}
}

##############################################################################
# modules/security/outputs.tf
##############################################################################
