# 🏠 Real-Time IoT Smart Home Monitoring & Alert System

[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.5.0-7B42BC?logo=terraform)](https://terraform.io)
[![GCP](https://img.shields.io/badge/Platform-Google%20Cloud-4285F4?logo=google-cloud)](https://cloud.google.com)
[![Region](https://img.shields.io/badge/Region-asia--southeast2%20(Jakarta)-34A853)](https://cloud.google.com/compute/docs/regions-zones)
[![Version](https://img.shields.io/badge/Release-v1.0.0-success)](CHANGELOG.md)

**Final Project — Cloud Computing | Teknik Informatika | Universitas Palangka Raya 2026**  
Dosen: Septian Geges, S.Kom., M.Kom.

---

## 👥 Tim Kelompok

| Nama | NIM | Role |
|------|-----|------|
| Bramatio Manjin | 2330205030052 | Cloud Architect |
| Ciko Christian | 2330205030059 | DevOps Engineer |
| Gregio Rafael Leon Jordan | 2330305030072 | Backend Developer |
| Haryadi Yusuf | 2330305030074 | **Security Engineer / Terraform Lead** |

---

## 📐 Arsitektur Sistem

```
Smart Home Sensors (Temp • Motion)
        │ MQTT
        ▼
  Cloud Pub/Sub ──────────────────────────────────────────────┐
  (iot-topic)                                                  │ Pub/Sub Trigger
        │ Push Subscription                                    │ & Auto Logging
        ▼                                                      │
  Cloud Run                                                    ▼
  (sensor-processor) ──── Database Write ──► Cloud SQL (MySQL)
        │                                                      │
        ├──── Store CSV/JSON Log ─────────► Cloud Storage      │
        │                                                      │
        └── Anomaly? ──► Cloud Pub/Sub ──► Push Notification ► Users
                         (iot-alert-topic)
        │
        ▼
  Google Cloud Operations Suite
  ├── Cloud Logging   (centralized log aggregation)
  └── Cloud Monitoring (dashboard + 7 alert policies)
```

---

## 🗂️ Struktur Repository

```
smarthome-iot/
├── .gitignore
├── README.md
├── CHANGELOG.md
├── terraform/
│   ├── main.tf              # Root module — memanggil semua child module
│   ├── variables.tf         # Semua input variables
│   ├── outputs.tf           # Output yang diekspor
│   ├── backend.tf           # Remote state di GCS
│   ├── terraform.tfvars.example
│   └── modules/
│       ├── networking/      # VPC, Subnet, Firewall, VPC Connector
│       ├── iam/             # Service Accounts, IAM bindings
│       ├── database/        # Cloud SQL MySQL 8.0 (Private IP, CMEK)
│       ├── storage/         # Cloud Storage (lifecycle, CMEK)
│       ├── secrets/         # Secret Manager
│       ├── pubsub/          # Pub/Sub topics & subscriptions
│       ├── artifact_registry/ # Docker registry (private)
│       ├── cloudrun/        # Cloud Run sensor-processor
│       ├── monitoring/      # Dashboard, alert policies, log sinks
│       ├── backup/          # Cloud Scheduler SQL export
│       └── security/        # SCC, Org Policy, Binary Auth
├── docs/
│   ├── security-architecture.md
│   ├── runbook.md
│   └── cloud-resource-inventory.md
└── scripts/
    ├── smoke-test.sh        # Pengujian cepat end-to-end
    └── load-test.sh         # Load test dengan k6
```

---

## 🚀 Setup & Deploy

### Prerequisites
```bash
# Install tools
brew install terraform google-cloud-sdk  # macOS
# atau: apt-get install terraform google-cloud-sdk  # Ubuntu

# Login ke GCP
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 1. Setup Remote State Backend
```bash
# Buat bucket untuk Terraform state (jalankan SEKALI)
gsutil mb -l asia-southeast2 gs://smarthome-tfstate-YOUR_PROJECT_ID
gsutil versioning set on gs://smarthome-tfstate-YOUR_PROJECT_ID

# Update bucket name di terraform/backend.tf
```

### 2. Konfigurasi Variables
```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — isi project_id dan alert_email
```

### 3. Deploy Infrastruktur
```bash
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

### 4. Verifikasi
```bash
# Lihat semua output
terraform output deployment_summary

# Smoke test
cd ../scripts && bash smoke-test.sh
```

---

## 🏗️ Modul Terraform

| Modul | Resource Utama | Minggu |
|-------|---------------|--------|
| `networking` | VPC, Subnet 10.0.1.0/24, Firewall Rules, VPC Connector | 1 |
| `iam` | 5 Service Accounts, IAM bindings least privilege | 1 |
| `database` | Cloud SQL MySQL 8.0, Private IP, CMEK, mTLS | 2 |
| `storage` | GCS Bucket, lifecycle 4-tier, CMEK, versioning | 2 |
| `secrets` | Secret Manager (DB creds, SSL certs) | 2 |
| `pubsub` | iot-topic, iot-alert-topic, push subscription | 2 |
| `artifact_registry` | Docker registry privat, vulnerability scan | 3 |
| `cloudrun` | sensor-processor Gen2, scale 0–3, VPC-native | 3 |
| `monitoring` | Dashboard 8 panel, 7 alert policies, log sinks | 4 |
| `backup` | Cloud Scheduler daily SQL export, backup bucket | 4 |
| `security` | SCC, Org Policy, Binary Auth, IAM alerts | 4 |

---

## 🔒 Security Design

### Prinsip yang Diterapkan
- **Least Privilege** — setiap Service Account hanya mendapat role minimum yang diperlukan
- **Zero Hardcoded Secrets** — semua credentials di Secret Manager, bukan di kode
- **Private Network** — Cloud SQL hanya bisa diakses via private IP dalam VPC
- **Encryption Everywhere** — CMEK (KMS) untuk Cloud SQL dan Cloud Storage, mTLS untuk koneksi DB
- **No Public Access** — `ipv4_enabled = false` pada Cloud SQL, `public_access_prevention = enforced` pada GCS
- **Security as Code** — semua konfigurasi keamanan dalam Terraform, tidak ada klik manual

### Firewall Rules
| Rule | Port | Source | Target |
|------|------|--------|--------|
| allow-internal | 3306, 8080 | 10.0.1.0/24 | smarthome-internal |
| allow-mqtt | 8883 (TLS), 1883 | 0.0.0.0/0 | smarthome-mqtt-broker |
| allow-health-check | 80, 443 | GCP LB ranges | smarthome-lb |
| allow-iap-ssh | 22 | 35.235.240.0/20 | smarthome-bastion |
| deny-all-ingress | all | 0.0.0.0/0 | (semua) |

---

## 💰 Estimasi Biaya

| Layanan | Biaya/Bulan |
|---------|------------|
| Cloud SQL (db-f1-micro, Jakarta) | $13.03 |
| Cloud Storage (Standard + Operations) | $0.25 |
| Cloud Run (50k req, scale-to-zero) | $0.19 |
| Pub/Sub + Logging + Monitoring | ~$0.01 |
| **Total** | **~$13.48** |

*Region asia-southeast2 (Jakarta) — estimasi per GCP Pricing Calculator, Juni 2026*

---

## 📊 Monitoring & Alerting

**7 Alert Policies aktif:**
1. Cloud Run CPU > 80% (duration 5 menit)
2. Cloud Run Error Rate > 5 req/min (duration 3 menit)
3. Cloud SQL Disk > 90% (duration 1 menit)
4. Cloud Run Latency p99 > 5 detik (duration 5 menit)
5. Pub/Sub Backlog > 1000 pesan (duration 5 menit)
6. Cloud Run Health Check Gagal (duration 1 menit)
7. IAM Policy Berubah — SECURITY ALERT (segera)

---

## 📋 Referensi

- [GCP Terraform Provider Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Cloud Run Security Best Practices](https://cloud.google.com/run/docs/securing/security-overview)
- [CIS Google Cloud Benchmark](https://www.cisecurity.org/benchmark/google_cloud_computing_platform)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

---

*Proyek ini dibuat untuk keperluan akademik — Final Project Cloud Computing, Universitas Palangka Raya, 2026.*
