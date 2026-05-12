# 🏡 Smart Home Monitoring System - Cloud Computing Project

Proyek ini adalah implementasi infrastruktur backend untuk sistem Smart Home berbasis IoT menggunakan **Google Cloud Platform (GCP)**. Sistem ini dirancang untuk menangani data stream dari sensor secara real-time, aman, dan scalable.

## 👥 Kelompok Proyek
| Nama Anggota | NIM | Peran |
| :--- | :--- | :--- |
| **Bramatio Manjin** | 2330205030052 | DevOps & Security Engineer |
| **Ciko Christian** | 2330205030059 | Cloud Architect |
| **Gregio Rafael Leon Jordan** | 2330305030072 | Backend Developer |
| **Haryadi Yusuf** | 2330305030074 | System Analyst |

---

## 🏗️ Arsitektur Sistem
Sistem menggunakan pendekatan **Hybrid (MQTT + HTTP)** untuk efisiensi komunikasi antara perangkat IoT dan aplikasi pengguna.

![Diagram Arsitektur](docs/Diagram%20GCP%20IoT%20(Dark).png)

### Alur Kerja:
1. **Sensor IoT:** Mengirim data suhu/gerakan melalui protokol MQTT ke **Cloud Pub/Sub**.
2. **Data Processing:** **Cloud Functions** terpicu secara otomatis untuk memproses data dari Pub/Sub.
3. **Storage:** Data hasil pemrosesan disimpan secara permanen di **Firestore (NoSQL)**.
4. **Monitoring & Logs:** Seluruh aktivitas dicatat di **Cloud Logging** dan dipantau melalui dashboard **Cloud Monitoring**.

---

## 🛡️ Implementasi Keamanan (Minggu 4)
Infrastruktur telah dikelola sepenuhnya menggunakan **Terraform (Infrastructure as Code)** dengan standar keamanan tinggi:

### 1. Data Protection (Enkripsi)
* **At-Rest:** Menggunakan **Cloud KMS** (Customer-Managed Encryption Keys) untuk enkripsi database Firestore dengan kebijakan rotasi kunci setiap 90 hari.
* **In-Transit:** Implementasi **SSL Policy** dengan profil TLS 1.2+ pada jalur komunikasi data.

### 2. IAM (Identity and Access Management)
Menggunakan prinsip **Least Privilege** dengan Service Account (SA) terpisah untuk setiap fungsi:
* `sa-iot-publisher`: Akses terbatas hanya untuk publish pesan ke Pub/Sub.
* `sa-data-processor`: Akses untuk memproses data dan menulis ke database.
* `sa-firestore-reader`: Akses read-only untuk kebutuhan dashboard aplikasi.
* `sa-storage-manager`: Pengelolaan log audit di Cloud Storage.

### 3. Audit Logging
Seluruh aktivitas infrastruktur dicatat melalui **Cloud Audit Logs** dan diekspor ke **Cloud Storage Bucket (Coldline)** via Log Sink untuk retensi data jangka panjang.

---

## 💰 Estimasi Biaya Bulanan (GCP)
Berdasarkan kalkulasi Cloud Architect, berikut proyeksi biaya operasional sistem:

| Layanan | Estimasi Biaya (IDR) | Keterangan |
| :--- | :--- | :--- |
| **Cloud Functions** | Rp 3.313,19 | Pemrosesan event-driven |
| **Cloud Storage** | Rp 4.248,90 | Penyimpanan Log & Backup |
| **Cloud Pub/Sub** | Rp 45,53 | Message Broker |
| **Cloud Logging** | Rp 158,38 | Retensi log 30 hari |
| **Firestore** | Rp 0,00 | Free Tier |
| **Total Estimasi** | **Rp 7.766,05** | *Affordable & Scalable* |

---

## 📂 Struktur Folder
* `/docs`: Berisi dokumentasi perencanaan (.pdf) dan diagram arsitektur.
* `/terraform`: Kode Infrastructure as Code (IaC) untuk otomasi GCP.
  * `/modules`: Modul terpisah untuk IAM dan Security.

---

## 🚀 Cara Replikasi Infrastruktur
1. Install Terraform.
2. `cd terraform`
3. `terraform init`
4. `terraform apply`