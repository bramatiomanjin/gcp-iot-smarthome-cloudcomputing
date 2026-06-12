# Security Architecture Document
## Real-Time IoT Smart Home Monitoring & Alert System — GCP
**Security Engineer: Haryadi Yusuf (2330305030074)**  
**Versi: v1.0.0 | Juni 2026**

---

## 1. Threat Model Ringkas

| Ancaman | Vektor | Mitigasi |
|---------|--------|----------|
| Unauthorized DB access | Internet → MySQL 3306 | Cloud SQL Private IP ONLY (`ipv4_enabled=false`) |
| Credential theft | Hardcoded credentials di kode | 100% Secret Manager, zero hardcoded |
| Man-in-the-middle | DB connection tanpa enkripsi | mTLS required (`ssl_mode=TRUSTED_CLIENT_CERTIFICATE_REQUIRED`) |
| Data exfiltration via storage | Bucket public access | `public_access_prevention=enforced`, Uniform ACL |
| Privilege escalation | SA dengan role berlebih | Least privilege — setiap SA hanya role minimum |
| Unauthorized container deploy | Arbitrary Docker image | Binary Authorization (audit mode) |
| IAM tampering | SetIamPolicy tanpa Terraform | Alert IAM policy change (segera) |
| Ransomware/delete attack | Delete Cloud SQL data | Automated backup + point-in-time recovery |

---

## 2. Network Security

```
Internet
   │
   │  MQTT port 8883 (TLS)
   ▼
[Firewall: allow-mqtt]
   │
   ▼
Cloud Pub/Sub (fully managed — tidak butuh port terbuka)
   │
   │  VPC Connector (internal)
   ▼
[Subnet 10.0.1.0/24 — Private Google Access ON]
   │
   ├──► Cloud Run (no public IP, ingress=INTERNAL_AND_CLOUD_LB)
   │          │ Cloud SQL Auth Proxy (Unix socket, mTLS)
   │          ▼
   └──► Cloud SQL (Private IP 10.x.x.x — NO public IP)

[Firewall: deny-all-ingress priority 65534 — explicit deny]
```

### Firewall Rule Priority Matrix
| Priority | Rule | Action |
|----------|------|--------|
| 1000 | allow-internal (10.0.1.0/24 → port 3306, 8080) | ALLOW |
| 1000 | allow-mqtt (0.0.0.0/0 → port 8883, 1883) | ALLOW |
| 1000 | allow-health-check (GCP LB → port 80, 443) | ALLOW |
| 1000 | allow-iap-ssh (35.235.240.0/20 → port 22) | ALLOW |
| 65534 | deny-all-ingress | DENY |

---

## 3. Identity & Access Management

### Service Accounts
| SA | Role | Justifikasi |
|----|------|-------------|
| sa-cloudrun-processor | cloudsql.client, storage.objectAdmin, secretmanager.secretAccessor, pubsub.publisher, logging.logWriter | Semua yang dibutuhkan Cloud Run untuk operasi normal |
| sa-pubsub-publisher | pubsub.publisher | Hanya publish, tidak bisa subscribe atau lihat isi pesan lain |
| sa-cloudsql-client | cloudsql.client | Hanya koneksi DB, tidak bisa manage instance |
| sa-monitoring | monitoring.viewer, logging.viewer, monitoring.metricWriter | Read-only untuk operasional, write untuk custom metrics |
| sa-storage-archiver | storage.objectCreator | Hanya bisa buat objek baru, tidak bisa hapus/ubah |
| sa-terraform-deploy | editor + projectIamAdmin | Deploy-only, digunakan CI/CD — TIDAK dibagikan ke individu |

### Prinsip Zero-Trust yang Diterapkan
- Tidak ada SA yang diberi `roles/owner` atau `roles/editor` selain sa-terraform
- Tidak ada service account key file yang dibuat (Org Policy enforced)
- Semua autentikasi menggunakan Workload Identity atau Application Default Credentials

---

## 4. Data Encryption

| Layer | Mekanisme | Key |
|-------|-----------|-----|
| Cloud SQL at-rest | CMEK via Cloud KMS | `smarthome-db-key` (rotation 90 hari) |
| Cloud Storage at-rest | CMEK via Cloud KMS | `smarthome-storage-key` (rotation 90 hari) |
| Cloud SQL in-transit | mTLS (ssl_mode=TRUSTED_CLIENT_CERTIFICATE_REQUIRED) | Client cert per SA |
| Secret Manager | Google-managed encryption | Automatic |
| VPC internal traffic | Google network encryption | Automatic |

---

## 5. Audit & Compliance

**Audit Logging aktif untuk semua services:**
- `ADMIN_READ` — siapa yang membaca konfigurasi
- `DATA_READ` — siapa yang membaca data
- `DATA_WRITE` — siapa yang menulis data
- Tidak ada exempted_members — semua tindakan diaudit

**Log Sinks ke Cloud Storage:**
- Cloud Run logs (severity ≥ WARNING)
- Cloud SQL logs (severity ≥ WARNING)  
- Security/Audit logs (cloudaudit, IAM, Secret Manager)

---

## 6. Security Monitoring

| Alert | Kondisi | Respons |
|-------|---------|---------|
| IAM Policy Change | SetIamPolicy terjadi | Investigasi segera — cek apakah via Terraform |
| Secret Manager Spike | > 100 akses / 5 menit | Kemungkinan credential stuffing |
| Cloud Run Health Check Gagal | /health tidak merespons | Restart atau rollback image |
| Cloud SQL Disk > 90% | Disk hampir penuh | Archive data lama ke GCS |
| Backup Job Gagal | Scheduler job gagal | Manual export segera |
