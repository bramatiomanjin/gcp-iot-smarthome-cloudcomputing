##############################################################################
# modules/iam/variables.tf
##############################################################################

variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "labels" {
  description = "Label resource"
  type        = map(string)
  default     = {}
}
