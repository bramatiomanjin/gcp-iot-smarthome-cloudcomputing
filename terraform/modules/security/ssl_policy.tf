resource "google_compute_ssl_policy" "smarthome_ssl_policy" {
  name            = "smarthome-ssl-policy"
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
  project         = var.project_id
}