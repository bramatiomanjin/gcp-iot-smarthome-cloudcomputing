# CHANGELOG
## Real-Time IoT Smart Home Monitoring & Alert System — GCP Infrastructure

Semua perubahan infrastruktur dicatat di sini.  
Format: **[versi] — tanggal | Minggu X**

---

## [v1.0.0] — Juni 2026 | Minggu 5 — FINAL RELEASE

### 🎓 Finalisasi
- Tag rilis `v1.0.0` sebagai versi final proyek akademik
- Cleanup komentar TODO dan placeholder di semua modul
- Penambahan label `version = "v1-0-0"` pada semua resource
- Update `cloudrun_image_tag` dari `latest` ke `v1.0.0`
- Penambahan `.gitignore`, `CHANGELOG.md`, `README.md` komprehensif
- Dokumentasi lengkap: `docs/security-architecture.md`, `docs/runbook.md`
- Script pengujian: `scripts/smoke-test.sh`, `scripts/load-test.sh`

---

## [v0.4.0] — Juni 2026 | Minggu 4 — Monitoring, Keamanan & Optimasi

### ✨ Modul Baru: `modules/monitoring`
- `google_monitoring_notification_channel` — email alert
- `google_logging_metric` x3 — error count, nack count, anomaly count
- `google_monitoring_alert_policy` x6 — CPU, error rate, disk, latency, Pub/Sub backlog, uptime
- `google_monitoring_dashboard` — 8-panel JSON dashboard
- `google_logging_project_sink` x3 — Cloud Run, Cloud SQL, Security → GCS
- `google_monitoring_uptime_check_config` — health check /health endpoint setiap 5 menit

### ✨ Modul Baru: `modules/backup`
- `google_storage_bucket` backup_bucket — Nearline, versioning, lifecycle 30 hari
- `google_service_account` sa-backup-scheduler
- `google_cloud_scheduler_job` daily_db_export — setiap hari 03:00 WIB
- `google_cloud_scheduler_job` weekly_csv_export — setiap Minggu 01:00 WIB
- `google_monitoring_alert_policy` backup_failure_alert

### ✨ Modul Baru: `modules/security`
- `google_scc_notification_config` — SCC findings ke Pub/Sub
- `google_project_organization_policy` x5 — no public IP, no SA key, restrict location, public access prevention, require OS login
- `google_binary_authorization_policy` — audit mode
- `google_binary_authorization_attestor` + `google_container_analysis_note`
- `google_project_iam_audit_config` — enhanced audit logging (ADMIN_READ, DATA_READ, DATA_WRITE)
- `google_logging_metric` x2 — secret access spike, IAM policy change
- `google_monitoring_alert_policy` x2 — IAM change, Secret Manager spike

### 🔒 Security Hardening
- Seluruh audit log diaktifkan tanpa exemption
- Binary Authorization dalam mode audit untuk semua container
- Org Policy: `sql.restrictPublicIp` = enforced
- Org Policy: `iam.disableServiceAccountKeyCreation` = enforced

---

## [v0.3.0] — Juni 2026 | Minggu 3 — Implementasi Layanan Inti

### ✨ Modul Baru: `modules/artifact_registry`
- `google_artifact_registry_repository` smarthome-registry (Docker, PRIVATE)
- IAM: CI/CD SA = writer, Cloud Run SA = reader, Cloud Build = writer
- Cleanup policy: hapus untagged images > 30 hari, pertahankan 5 versi

### ✨ Modul Baru: `modules/cloudrun`
- `google_cloud_run_v2_service` sensor-processor (Gen2 execution environment)
- Ingress: `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER` — tidak ada akses publik langsung
- VPC Connector untuk akses Cloud SQL private
- Auto-scaling: min=0 (scale-to-zero), max=3
- Semua env vars dari Secret Manager (zero hardcoded credentials)
- Startup CPU boost diaktifkan untuk cold start

### 🔄 Update Modul `modules/pubsub`
- Push endpoint diubah dari placeholder ke URL Cloud Run nyata
- Dependency eksplisit ke module.cloudrun

---

## [v0.2.0] — Juni 2026 | Minggu 2 — Implementasi Infrastruktur Dasar

### ✨ Modul Baru: `modules/database`
- `google_sql_database_instance` iot-db (MySQL 8.0, db-f1-micro, Private IP ONLY)
- CMEK enkripsi at-rest dengan KMS Key Ring + Crypto Key (rotation 90 hari)
- SSL/TLS required (ssl_mode = TRUSTED_CLIENT_CERTIFICATE_REQUIRED)
- Automated backup harian 02:00 WIB, retensi 7 hari, binary log enabled
- Database flags: skip_show_database=ON, local_infile=OFF, slow_query_log=ON
- `google_sql_ssl_cert` cloudrun-client-cert untuk mTLS

### ✨ Modul Baru: `modules/storage`
- `google_storage_bucket` smarthome-sensor-logs (Standard + versioning + CMEK)
- Public Access Prevention = enforced
- Lifecycle 4 lapis: Standard → Nearline (30hr) → Coldline (90hr) → Delete (365hr)

### ✨ Modul Baru: `modules/secrets`
- `google_secret_manager_secret` db-password, db-connection-string, db-ssl-*
- IAM accessor: Cloud Run SA only
- Semua nilai sensitif tidak ada di kode Terraform

### ✨ Modul Baru: `modules/pubsub` (versi awal)
- `google_pubsub_topic` iot-topic + iot-alert-topic
- `google_pubsub_subscription` cloudrun-push (push type, URL = placeholder)
- Dead letter policy untuk pesan yang gagal diproses

---

## [v0.1.0] — Juni 2026 | Minggu 1 — Perencanaan & Arsitektur

### ✨ Modul Baru: `modules/networking`
- `google_compute_network` smarthome-vpc (custom subnet, non-auto)
- `google_compute_subnetwork` smarthome-subnet (10.0.1.0/24, Private Google Access, Flow Logs)
- `google_compute_global_address` private-ip-range untuk Private Service Connection
- `google_service_networking_connection` VPC peering ke servicenetworking.googleapis.com
- `google_vpc_access_connector` smarthome-connector (e2-micro, 2-3 instances)
- Firewall rules: allow-internal, allow-mqtt, allow-health-check, allow-iap-ssh, deny-all-ingress

### ✨ Modul Baru: `modules/iam`
- Service accounts: sa-cloudrun-processor, sa-pubsub-publisher, sa-cloudsql-client, sa-monitoring, sa-storage-archiver, sa-terraform-deploy
- IAM bindings least privilege: setiap SA hanya mendapat role yang diperlukan
- `google_project_iam_audit_config` untuk semua services

### 📋 Infrastruktur Awal
- `terraform.tfvars.example` dibuat sebagai template
- Backend GCS dikonfigurasi untuk remote state
- Provider constraints: google ~> 5.0, terraform >= 1.5.0
