##############################################################################
# modules/networking/main.tf
# Infrastruktur jaringan: VPC, Subnet, Firewall Rules, Private Google Access,
# Serverless VPC Access Connector
##############################################################################

# ─── VPC ─────────────────────────────────────────────────────────────────────

resource "google_compute_network" "vpc" {
  name                    = var.vpc_name
  project                 = var.project_id
  auto_create_subnetworks = false   # Custom subnet mode — best practice keamanan
  description             = "VPC utama untuk Smart Home Monitoring System — GCP"
  routing_mode            = "REGIONAL"
}

# ─── Subnet ──────────────────────────────────────────────────────────────────

resource "google_compute_subnetwork" "subnet" {
  name                     = var.subnet_name
  project                  = var.project_id
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.subnet_cidr
  private_ip_google_access = true   # Instance tanpa IP publik tetap bisa akses GCP API

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# ─── Private Service Access (untuk Cloud SQL Private IP) ─────────────────────

resource "google_compute_global_address" "private_service_range" {
  name          = "${var.vpc_name}-private-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 20
  network       = google_compute_network.vpc.id
  description   = "Alokasi IP untuk koneksi private Cloud SQL"
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]

  depends_on = [google_compute_global_address.private_service_range]
}

# ─── Serverless VPC Access Connector ─────────────────────────────────────────
# Diperlukan agar Cloud Run dapat menjangkau Cloud SQL via private IP

resource "google_vpc_access_connector" "connector" {
  name          = "smarthome-connector"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.8.0.0/28"   # /28 khusus untuk VPC connector, tidak boleh overlap
  min_instances = 2
  max_instances = 3
  machine_type  = "e2-micro"

  depends_on = [google_compute_subnetwork.subnet]
}

# ─── Firewall Rules ──────────────────────────────────────────────────────────
# Prinsip: least privilege — hanya izinkan traffic yang benar-benar dibutuhkan

# 1. Izinkan komunikasi internal dalam VPC (Cloud SQL, Cloud Run via VPC connector)
resource "google_compute_firewall" "allow_internal" {
  name        = "${var.vpc_name}-allow-internal"
  project     = var.project_id
  network     = google_compute_network.vpc.name
  description = "Izin akses internal VPC: Cloud SQL (3306) dan Cloud Run (8080)"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["3306", "8080", "8443"]
  }

  source_ranges = [var.subnet_cidr, "10.8.0.0/28"]   # Subnet + VPC connector range

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# 2. Izinkan traffic MQTT dari perangkat sensor IoT
resource "google_compute_firewall" "allow_mqtt" {
  name        = "${var.vpc_name}-allow-mqtt"
  project     = var.project_id
  network     = google_compute_network.vpc.name
  description = "Izin lalu lintas MQTT (port 1883 plain, 8883 TLS) dari sensor IoT"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["1883", "8883"]
  }

  # CATATAN KEAMANAN: Untuk production, ganti 0.0.0.0/0 dengan IP range
  # perangkat IoT yang diketahui. Gunakan 8883 (TLS) dan nonaktifkan 1883.
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["mqtt-device"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# 3. Izinkan health check dari Google Cloud Load Balancer
resource "google_compute_firewall" "allow_health_check" {
  name        = "${var.vpc_name}-allow-health-check"
  project     = var.project_id
  network     = google_compute_network.vpc.name
  description = "Izin Google Cloud health check untuk load balancer"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080"]
  }

  # Range IP resmi Google untuk health check
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["load-balanced"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# 4. Izinkan SSH hanya dari IAP (Identity-Aware Proxy) — tidak boleh direct SSH
resource "google_compute_firewall" "allow_iap_ssh" {
  name        = "${var.vpc_name}-allow-iap-ssh"
  project     = var.project_id
  network     = google_compute_network.vpc.name
  description = "Izin SSH hanya melalui IAP — akses langsung dari internet diblokir"
  direction   = "INGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Range IP khusus Google IAP
  source_ranges = ["35.235.240.0/20"]

  log_config {
    metadata = "INCLUDE_ALL_METADATA"
  }
}

# 5. Blokir semua egress ke internet kecuali yang eksplisit diizinkan
#    (default GCP: allow all egress — kita override untuk keamanan)
resource "google_compute_firewall" "deny_egress_default" {
  name        = "${var.vpc_name}-deny-egress-default"
  project     = var.project_id
  network     = google_compute_network.vpc.name
  description = "Deny semua egress internet — override default GCP untuk keamanan"
  direction   = "EGRESS"
  priority    = 65534

  deny {
    protocol = "all"
  }

  destination_ranges = ["0.0.0.0/0"]
}

# 6. Izinkan egress ke Google APIs (via Private Google Access range)
resource "google_compute_firewall" "allow_egress_google_apis" {
  name        = "${var.vpc_name}-allow-egress-google-apis"
  project     = var.project_id
  network     = google_compute_network.vpc.name
  description = "Izin egress ke Google APIs melalui Private Google Access"
  direction   = "EGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["443", "80"]
  }

  destination_ranges = [
    "199.36.153.8/30",    # restricted.googleapis.com
    "199.36.153.4/30",    # private.googleapis.com
    "34.126.0.0/18",      # asia-southeast2 Google APIs
  ]
}

# 7. Izinkan egress ke Cloud SQL (3306) via private IP
resource "google_compute_firewall" "allow_egress_cloudsql" {
  name        = "${var.vpc_name}-allow-egress-cloudsql"
  project     = var.project_id
  network     = google_compute_network.vpc.name
  description = "Izin egress ke Cloud SQL via peering range"
  direction   = "EGRESS"
  priority    = 1000

  allow {
    protocol = "tcp"
    ports    = ["3306", "5432"]
  }

  destination_ranges = ["10.0.0.0/8"]   # Seluruh private RFC-1918 (termasuk SQL peering)
}
