##############################################################################
# modules/database/outputs.tf
##############################################################################

output "instance_name" {
  description = "Nama instance Cloud SQL"
  value       = google_sql_database_instance.main.name
}

output "instance_connection_name" {
  description = "Connection name Cloud SQL (format: project:region:instance)"
  value       = google_sql_database_instance.main.connection_name
}

output "private_ip_address" {
  description = "Private IP address Cloud SQL instance"
  value       = google_sql_database_instance.main.private_ip_address
  sensitive   = true
}

output "database_name" {
  description = "Nama database"
  value       = google_sql_database.smarthome.name
}

output "db_user" {
  description = "Username database"
  value       = google_sql_user.iot_user.name
}

output "db_password" {
  description = "Password database (sensitive — simpan ke Secret Manager)"
  value       = random_password.db_password.result
  sensitive   = true
}

output "ssl_cert_server_ca" {
  description = "Server CA certificate Cloud SQL"
  value       = google_sql_database_instance.main.server_ca_cert[0].cert
  sensitive   = true
}

output "ssl_client_cert" {
  description = "Client certificate untuk Cloud Run"
  value       = google_sql_ssl_cert.cloudrun_cert.cert
  sensitive   = true
}

output "ssl_client_key" {
  description = "Client private key untuk Cloud Run"
  value       = google_sql_ssl_cert.cloudrun_cert.private_key
  sensitive   = true
}

output "kms_key_id" {
  description = "ID KMS key yang digunakan untuk CMEK enkripsi Cloud SQL"
  value       = google_kms_crypto_key.sql_key.id
}
