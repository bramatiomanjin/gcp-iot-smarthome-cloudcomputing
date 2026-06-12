# Tabel Inventaris Cloud Resources — Minggu 2
## Smart Home IoT Monitoring System — GCP
*Update: Minggu 2 | Security Engineer: Haryadi Yusuf | Dikelola via Terraform*

---

## Minggu 1 — Infrastruktur Jaringan & IAM ✅

| No | Resource Name | Tipe Resource GCP | Region | Modul Terraform | Tujuan |
|----|---------------|-------------------|--------|-----------------|--------|
| 1 | `smarthome-vpc` | `google_compute_network` | Global | `modules/networking` | VPC utama isolasi jaringan |
| 2 | `smarthome-subnet` | `google_compute_subnetwork` | asia-southeast2 | `modules/networking` | Subnet utama 10.0.1.0/24, Private Google Access ON |
| 3 | `smarthome-connector` | `google_vpc_access_connector` | asia-southeast2 | `modules/networking` | VPC Access untuk Cloud Run — range 10.8.0.0/28 |
| 4 | `smarthome-vpc-private-range` | `google_compute_global_address` | Global | `modules/networking` | Private Service Access untuk Cloud SQL (VPC Peering) |
| 5 | `smarthome-vpc-allow-internal` | `google_compute_firewall` | Global | `modules/networking` | Izin TCP 3306, 8080, 8443 dari subnet + VPC connector |
| 6 | `smarthome-vpc-allow-mqtt` | `google_compute_firewall` | Global | `modules/networking` | Izin TCP 1883 (MQTT), 8883 (MQTT/TLS) dari sensor IoT |
| 7 | `smarthome-vpc-allow-health-check` | `google_compute_firewall` | Global | `modules/networking` | Izin health check dari Google LB range |
| 8 | `smarthome-vpc-allow-iap-ssh` | `google_compute_firewall` | Global | `modules/networking` | SSH hanya via IAP (35.235.240.0/20) |
| 9 | `smarthome-vpc-deny-egress-default` | `google_compute_firewall` | Global | `modules/networking` | Deny ALL egress (override default GCP) |
| 10 | `smarthome-vpc-allow-egress-google-apis` | `google_compute_firewall` | Global | `modules/networking` | Whitelist egress HTTPS ke Google APIs via Private Google Access |
| 11 | `smarthome-vpc-allow-egress-cloudsql` | `google_compute_firewall` | Global | `modules/networking` | Egress TCP 3306/5432 ke Cloud SQL via private peering |
| 12 | `sa-cloudrun-processor` | `google_service_account` | Global | `modules/iam` | SA untuk Cloud Run: SQL client, Secret Accessor, Storage Writer, Pub/Sub Publisher |
| 13 | `sa-pubsub-invoker` | `google_service_account` | Global | `modules/iam` | SA untuk Pub/Sub push — hanya roles/run.invoker |
| 14 | `sa-cloudsql` | `google_service_account` | Global | `modules/iam` | SA untuk Cloud SQL backup/export ke GCS |
| 15 | `sa-monitoring` | `google_service_account` | Global | `modules/iam` | SA untuk Cloud Monitoring dan Logging viewer |
| 16 | `sa-cicd-deploy` | `google_service_account` | Global | `modules/iam` | SA untuk CI/CD: Cloud Run developer, AR writer |

---

## Minggu 2 — Layanan Core + Keamanan ✅ (Baru)

### Cloud SQL (Database)

| No | Resource Name | Tipe Resource GCP | Region | Modul | Tujuan |
|----|---------------|-------------------|--------|-------|--------|
| 17 | `cloud-computing-495107-sql-keyring` | `google_kms_key_ring` | asia-southeast2 | `modules/database` | KMS Key Ring untuk CMEK Cloud SQL |
| 18 | `smarthome-sql-key` | `google_kms_crypto_key` | asia-southeast2 | `modules/database` | Customer-Managed Encryption Key — rotasi 90 hari |
| 19 | `iot-db` | `google_sql_database_instance` | asia-southeast2 | `modules/database` | Cloud SQL MySQL 8.0, Private IP ONLY, db-f1-micro, backup harian pukul 02:00 |
| 20 | `smarthome` | `google_sql_database` | — | `modules/database` | Database utama, charset utf8mb4 |
| 21 | `iot_user` | `google_sql_user` | — | `modules/database` | User database dengan password random 32 karakter |
| 22 | `cloudrun-client-cert` | `google_sql_ssl_cert` | — | `modules/database` | SSL client certificate untuk mTLS Cloud Run ke Cloud SQL |

### Cloud Storage

| No | Resource Name | Tipe Resource GCP | Region | Modul | Tujuan |
|----|---------------|-------------------|--------|-------|--------|
| 23 | `cloud-computing-495107-storage-keyring` | `google_kms_key_ring` | asia-southeast2 | `modules/storage` | KMS Key Ring untuk CMEK Cloud Storage |
| 24 | `smarthome-storage-key` | `google_kms_crypto_key` | asia-southeast2 | `modules/storage` | Customer-Managed Encryption Key — rotasi 90 hari |
| 25 | `smarthome-sensor-logs-cloud-computing-495107` | `google_storage_bucket` | asia-southeast2 | `modules/storage` | Bucket sensor log: versioning ON, public access prevention ENFORCED, lifecycle 30/90/365 hari |
| 26 | `smarthome-sensor-logs-...-access-logs` | `google_storage_bucket` | asia-southeast2 | `modules/storage` | Bucket audit trail akses ke bucket utama |

### Cloud Pub/Sub

| No | Resource Name | Tipe Resource GCP | Region | Modul | Tujuan |
|----|---------------|-------------------|--------|-------|--------|
| 27 | `iot-topic` | `google_pubsub_topic` | Global | `modules/pubsub` | Topik utama ingesti data sensor — retensi 7 hari |
| 28 | `iot-alert-topic` | `google_pubsub_topic` | Global | `modules/pubsub` | Topik distribusi alert ke pengguna — retensi 1 hari |
| 29 | `iot-topic-dead-letter` | `google_pubsub_topic` | Global | `modules/pubsub` | Dead-letter topic untuk pesan gagal — retensi 30 hari |
| 30 | `sensor-data-schema` | `google_pubsub_schema` | Global | `modules/pubsub` | Avro schema validasi struktur pesan sensor |
| 31 | `iot-topic-cloudrun-push` | `google_pubsub_subscription` | Global | `modules/pubsub` | Push subscription ke Cloud Run, DLQ setelah 5 gagal, retry exponential backoff |
| 32 | `iot-topic-dead-letter-pull` | `google_pubsub_subscription` | Global | `modules/pubsub` | Pull subscription untuk monitoring dead-letter messages |
| 33 | `iot-alert-topic-push` | `google_pubsub_subscription` | Global | `modules/pubsub` | Push subscription untuk distribusi notifikasi alert |

### Secret Manager

| No | Resource Name | Tipe Resource GCP | Region | Modul | Tujuan |
|----|---------------|-------------------|--------|-------|--------|
| 34 | `db-password` | `google_secret_manager_secret` | asia-southeast2 | `modules/secrets` | Password database iot_user (32 karakter random) |
| 35 | `db-connection-string` | `google_secret_manager_secret` | asia-southeast2 | `modules/secrets` | Connection string lengkap MySQL untuk Cloud Run |
| 36 | `db-ssl-client-cert` | `google_secret_manager_secret` | asia-southeast2 | `modules/secrets` | SSL client certificate untuk mTLS ke Cloud SQL |
| 37 | `db-ssl-client-key` | `google_secret_manager_secret` | asia-southeast2 | `modules/secrets` | SSL client private key |
| 38 | `db-server-ca` | `google_secret_manager_secret` | asia-southeast2 | `modules/secrets` | Server CA certificate Cloud SQL |

---

## Ringkasan Resource per Minggu

| Minggu | Jumlah Resource | Modul Baru | Status |
|--------|-----------------|------------|--------|
| Minggu 1 | 16 resource | networking, iam | ✅ Deployed |
| Minggu 2 | 22 resource baru (total 38) | database, storage, pubsub, secrets | ✅ Deployed |
| Minggu 3 | +4 resource (Cloud Run, dll.) | cloudrun | 🔄 In Progress |
| Minggu 4 | +N resource (Monitoring, Alert) | monitoring | ⏳ Planned |

---

## Konfigurasi IAM Role Bindings (Lengkap)

| Service Account | Resource | Role GCP | Justifikasi |
|----------------|----------|----------|-------------|
| `sa-cloudrun-processor` | Project | `roles/cloudsql.client` | Koneksi ke Cloud SQL via auth proxy |
| `sa-cloudrun-processor` | Project | `roles/secretmanager.secretAccessor` | Baca credentials DB dari Secret Manager |
| `sa-cloudrun-processor` | Project | `roles/storage.objectCreator` | Tulis log sensor ke GCS bucket |
| `sa-cloudrun-processor` | Project | `roles/pubsub.publisher` | Publish pesan alert ke iot-alert-topic |
| `sa-cloudrun-processor` | Project | `roles/logging.logWriter` | Tulis application log ke Cloud Logging |
| `sa-cloudrun-processor` | Project | `roles/monitoring.metricWriter` | Tulis custom metrics ke Cloud Monitoring |
| `sa-pubsub-invoker` | Project | `roles/run.invoker` | Invoke Cloud Run endpoint dari Pub/Sub push |
| `sa-cloudsql` | Bucket | `roles/storage.objectAdmin` | Export backup Cloud SQL ke GCS |
| `sa-monitoring` | Project | `roles/monitoring.viewer` | Baca metrik untuk dashboard |
| `sa-monitoring` | Project | `roles/logging.viewer` | Baca log untuk analisis |
| `sa-cicd-deploy` | Project | `roles/run.developer` | Deploy update ke Cloud Run |
| `sa-cicd-deploy` | Project | `roles/artifactregistry.writer` | Push Docker image ke Artifact Registry |
| `sa-cicd-deploy` | Secret | `roles/secretmanager.secretAccessor` | Inject secrets saat deployment |
| `gcp-sa-cloud-sql` (built-in) | KMS Key | `roles/cloudkms.cryptoKeyEncrypterDecrypter` | CMEK enkripsi Cloud SQL |
| `gs-project-accounts` (built-in) | KMS Key | `roles/cloudkms.cryptoKeyEncrypterDecrypter` | CMEK enkripsi Cloud Storage |
| `gcp-sa-pubsub` (built-in) | DLQ Topic | `roles/pubsub.publisher` | Pub/Sub publish ke dead-letter topic |
