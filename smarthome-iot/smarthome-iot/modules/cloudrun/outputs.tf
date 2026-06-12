##############################################################################
# modules/cloudrun/outputs.tf
##############################################################################

output "service_name" {
  description = "Nama Cloud Run service"
  value       = google_cloud_run_v2_service.sensor_processor.name
}

output "service_url" {
  description = "URL HTTPS endpoint Cloud Run (digunakan sebagai Pub/Sub push endpoint)"
  value       = google_cloud_run_v2_service.sensor_processor.uri
}

output "service_id" {
  description = "Resource ID Cloud Run service"
  value       = google_cloud_run_v2_service.sensor_processor.id
}

output "latest_revision" {
  description = "Nama revision terbaru yang di-deploy"
  value       = google_cloud_run_v2_service.sensor_processor.latest_created_revision
}

output "ingress_setting" {
  description = "Ingress setting aktif"
  value       = google_cloud_run_v2_service.sensor_processor.ingress
}
