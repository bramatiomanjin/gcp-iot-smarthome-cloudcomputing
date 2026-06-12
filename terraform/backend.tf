##############################################################################
# backend.tf
# Terraform remote state disimpan di Google Cloud Storage
# Pastikan bucket sudah dibuat sebelum terraform init
##############################################################################

terraform {
  backend "gcs" {
    bucket = "smarthome-iot-tfstate-cloud-computing-495107"   # Bucket untuk remote state
    prefix = "terraform/state"
  }
}
