output "sa_iot_publisher_email" {
  value = google_service_account.sa_iot_publisher.email
}

output "sa_data_processor_email" {
  value = google_service_account.sa_data_processor.email
}

output "sa_monitoring_agent_email" {
  value = google_service_account.sa_monitoring_agent.email
}