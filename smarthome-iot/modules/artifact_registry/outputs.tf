##############################################################################
# modules/artifact_registry/outputs.tf
##############################################################################

output "repository_id" {
  description = "ID Artifact Registry repository"
  value       = google_artifact_registry_repository.smarthome_registry.repository_id
}

output "repository_name" {
  description = "Nama lengkap repository"
  value       = google_artifact_registry_repository.smarthome_registry.name
}

output "registry_hostname" {
  description = "Hostname registry (untuk docker push/pull)"
  value       = "${var.region}-docker.pkg.dev"
}

output "image_base_url" {
  description = "Base URL untuk image (prefix sebelum nama:tag)"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.smarthome_registry.repository_id}"
}

output "sensor_processor_image" {
  description = "URL lengkap image sensor-processor (tag: latest)"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.smarthome_registry.repository_id}/sensor-processor:latest"
}
