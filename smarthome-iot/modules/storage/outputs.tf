##############################################################################
# modules/storage/outputs.tf
##############################################################################

output "bucket_name" {
  description = "Nama bucket sensor log utama"
  value       = google_storage_bucket.sensor_logs.name
}

output "bucket_url" {
  description = "URL bucket (gs://...)"
  value       = google_storage_bucket.sensor_logs.url
}

output "access_logs_bucket_name" {
  description = "Nama bucket access log"
  value       = google_storage_bucket.access_logs.name
}

output "kms_key_id" {
  description = "ID KMS key yang digunakan untuk CMEK enkripsi Cloud Storage"
  value       = google_kms_crypto_key.storage_key.id
}
