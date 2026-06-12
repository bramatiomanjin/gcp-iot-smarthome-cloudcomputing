##############################################################################
# modules/networking/outputs.tf
##############################################################################

output "vpc_id" {
  description = "Self-link VPC"
  value       = google_compute_network.vpc.id
}

output "vpc_name" {
  description = "Nama VPC"
  value       = google_compute_network.vpc.name
}

output "subnet_id" {
  description = "Self-link subnet utama"
  value       = google_compute_subnetwork.subnet.id
}

output "subnet_name" {
  description = "Nama subnet utama"
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_cidr" {
  description = "CIDR subnet utama"
  value       = google_compute_subnetwork.subnet.ip_cidr_range
}

output "vpc_connector_id" {
  description = "ID Serverless VPC Access Connector"
  value       = google_vpc_access_connector.connector.id
}

output "vpc_connector_name" {
  description = "Nama VPC connector"
  value       = google_vpc_access_connector.connector.name
}

output "private_service_range_name" {
  description = "Nama global address untuk Private Service Access"
  value       = google_compute_global_address.private_service_range.name
}
