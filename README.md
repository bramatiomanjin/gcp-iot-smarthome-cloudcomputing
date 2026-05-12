# 🏡 Smart Home Monitoring System - Cloud Computing Project

Proyek ini adalah implementasi infrastruktur backend untuk sistem Smart Home berbasis IoT menggunakan **Google Cloud Platform (GCP)**.

## 👥 Kelompok Proyek
| Nama Anggota | NIM | Peran |
| :--- | :--- | :--- |
| **Bramatio Manjin** | 2330205030052 | DevOps & Security Engineer |
| **Ciko Christian** | 2330205030059 | Cloud Architect |
| **Gregio Rafael Leon Jordan** | 2330305030072 | Backend Developer |
| **Haryadi Yusuf** | 2330305030074 | System Analyst |

---

## 🏗️ Arsitektur Sistem
![Diagram Arsitektur](docs/diagram-arsitektur-gcp.png)

### Alur Kerja:
1. **Sensor IoT:** Mengirim data suhu/gerakan melalui protokol MQTT ke **Cloud Pub/Sub**.
2. **Data Processing:** **Cloud Functions** terpicu secara otomatis untuk memproses data.
3. **Storage:** Data disimpan secara permanen di **Firestore (NoSQL)**.

---

## 🛡️ Implementasi Keamanan (Minggu 4)
Infrastruktur dikelola menggunakan **Terraform** dengan standar keamanan:
* **Cloud KMS:** Enkripsi database Firestore (Customer-Managed Encryption Keys).
* **IAM Least Privilege:** Penggunaan Service Account terpisah (`sa-iot-publisher`, `sa-data-processor`, dll).
* **Audit Logging:** Pencatatan aktivitas sistem ke Cloud Storage via Log Sink.

---

## 💰 Estimasi Biaya Bulanan (GCP)
| Layanan | Estimasi Biaya (IDR) |
| :--- | :--- |
| **Cloud Functions** | Rp 3.313,19 |
| **Cloud Storage** | Rp 4.248,90 |
| **Cloud Pub/Sub** | Rp 45,53 |
| **Total Estimasi** | **Rp 7.766,05** |

---

## 📂 Struktur Folder
* `/docs`: Berisi [Dokumen Perencanaan](docs/dokumen-perencanaan-cc.pdf) dan [Diagram Arsitektur](docs/diagram-arsitektur-gcp.png).
* `/terraform`: Kode Infrastructure as Code (IaC) modular.

---

## 🚀 Cara Replikasi
1. `cd terraform`
2. `terraform init`
3. `terraform apply`