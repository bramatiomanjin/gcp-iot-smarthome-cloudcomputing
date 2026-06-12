# 🏡 Real-Time IoT Smart Home Monitoring & Alert System
> **Proyek Akhir Mata Kuliah Cloud Computing — Jurusan Teknik Informatika, Universitas Palangka Raya (UPR)**
> 👨‍🏫 **Dosen Pengampu:** Septian Geges, S.Kom., M.Kom.
> 🔗 **Production Repository:** [bramatiomanjin/gcp-iot-smarthome-cloudcomputing](https://github.com/bramatiomanjin/gcp-iot-smarthome-cloudcomputing)

---

## 👥 Tim Pengembang & Distribusi Peran
Eksplorasi infrastruktur ini dikembangkan secara kolaboratif menggunakan *Git Version Control* dengan matriks tanggung jawab yang selaras dengan dokumen perencanaan resmi tim:

| Foto / Avatar | Anggota Tim | NIM | Peran Utama | Fokus Kontribusi & Cakupan Teknis |
| :---: | :--- | :---: | :--- | :--- |
| 🧑‍💻 | **Bramatio Manjin** | `2330205030052` | **DevOps Engineer** | Arsitektur Git & branching, multi-layer `.gitignore`, manajemen state IaC, otomatisasi orkestrasi resource, dan standarisasi dokumentasi. |
| 📐 | **Ciko Christian** | `2330205030059` | **Cloud Architect** | Perancangan blueprint arsitektur sistem, pemetaan topologi jaringan cloud, penyusunan dependensi, serta optimasi *Cost-Awareness*. |
| 🚀 | **Gregio Rafael Leon Jordan** | `2330305030072` | **Backend Developer** | Implementasi kode program serverless (Cloud Run/Functions), penanganan data ingestion via Pub/Sub, dan penyusunan policy IAM. |
| 🛡️ | **Haryadi Yusuf** | `2330305030074` | **Security Engineer** | Hardening infrastruktur (CMEK, Secret Manager), penyusunan 8-panel Monitoring Dashboard, otomasi 7 log alert, dan disaster recovery (backup). |

---

## 🏗️ Arsitektur Repositori & Navigasi Dokumen (IaC Modular)
Proyek ini mengadopsi standar industri **Modular Infrastructure as Code (IaC)** menggunakan Terraform. Anda dapat mengklik langsung tautan berkas interaktif di bawah ini untuk meninjau dokumentasi perencanaan:

| Jalur Direktori / Berkas | Tipe Dokumen | Deskripsi & Fungsi Sistem |
| :--- | :--- | :--- |
| 📄 **[README.md](README.md)** | Markdown | Panduan utama repositori, distribusi peran tim, dan ringkasan progres. |
| 📁 **docs/** | Folder | Direktori penyimpanan seluruh aset dokumentasi perencanaan sistem. |
| ├── 🗺️ **[diagram-arsitektur-gcp.JPEG](docs/diagram-arsitektur-gcp.JPEG)** | Image/JPEG | Blueprint topologi dan alur data stream IoT real-time pada Google Cloud. |
| ├── 📕 **[dokumen-perencanaan-cc.pdf](docs/dokumen-perencanaan-cc.pdf)** | PDF Document | Landasan teori, analisis kebutuhan sistem, dan draf final UPR. |
| └── 📊 **[estimasi-biaya-gcp.csv](docs/estimasi-biaya-gcp.csv)** | CSV Spreadsheet | Hasil riil kalkulasi pengeluaran bulanan via GCP Billing Calculator. |
| 📁 **terraform/** | Folder | Direktori utama tempat orkestrasi kode *Infrastructure as Code* (IaC). |
| ├── 🛡️ **[.gitignore](terraform/.gitignore)** | Git Config | Proteksi lokal penahan file sensitif (kunci `.json` dan status `.tfstate`). |
| ├── ⚙️ **[main.tf](terraform/main.tf)** | Terraform Code | Root konfigurasi untuk memanggil seluruh sub-modul infrastruktur. |
| ├── 📋 **[variables.tf](terraform/variables.tf)** | Terraform Code | Variabel global lingkungan cloud (Region, Project ID, dll). |
| └── 📁 **modules/** | Folder | Kumpulan modul infrastruktur terisolasi (`networking`, `database`, `pubsub`, `cloudrun`, `monitoring`, dll). |

---

## ⚙️ Ringkasan Implementasi & Progres Proyek

### 🔒 Minggu 1 & 2: Lapisan Jaringan & Keamanan Data Dasar
* **Isolated Networking:** Berhasil mengisolasi seluruh infrastruktur backend di dalam Google Virtual Private Cloud (VPC) khusus, lengkap dengan pembatasan hak akses melalui **9 aturan Firewall** yang ketat.
* **Identity & Access Management (IAM):** Menerapkan prinsip *Least Privilege* secara ketat dengan memisahkan hak otorisasi ke dalam **5 Service Accounts** yang berbeda guna membatasi celah keamanan.
* **Data Persistence & Encryption:** Menyediakan instance **Cloud SQL (MySQL Private IP)** yang dilindungi oleh kunci enkripsi bawaan pengguna (**CMEK**), serta **Cloud Storage** yang dikonfigurasi dengan aturan siklus hidup otomatis (*Lifecycle Management*).
* **Ingestion Layer:** Membangun pipeline penangkapan data sensor IoT menggunakan **Google Cloud Pub/Sub** yang dilengkapi skema penanganan pesan gagal via *Dead Letter Queue* (DLQ).

### 📈 Minggu 3 & 4: Komputasi Serverless, Observabilitas, & Pengendalian Biaya
* **Serverless Compute Layer:** Memanfaatkan **Cloud Run Functions** untuk memproses payload sensor secara *asynchronous* dengan kebijakan otomatisasi mati jika kosong (*scale-to-zero*) demi efisiensi biaya yang masif.
* **Observability Suite:** Mengonfigurasi **Cloud Monitoring Dashboard** terpusat (terdiri dari widget performa database, request count, metrik temperatur, log sensor gerak, dll) beserta **7 aturan Alerting** otomatis berbasis tingkat keparahan (*High, Medium, Critical*) langsung ke email tim.
* **Repository Hardening:** Mengimplementasikan `.gitignore` berlapis (di tingkat *root* dan folder *terraform/*) untuk memastikan berkas sensitif seperti kunci akun `.json` dan status `.tfstate` tidak terekspos ke ruang publik.

---

## ⚠️ Manajemen Kendala & Solusi Teknis (*Lessons Learned*)

Dalam tahapan eksekusi otomatisasi infrastruktur menggunakan Terraform, tim mengidentifikasi beberapa kendala dependensi *resource* yang berhasil diatasi melalui pendekatan berikut:

> **1. Masalah Urutan Dependensi (Dependency Ordering) pada Cloud SQL**
> * **Kendala:** Proses `terraform apply` gagal karena mesin Terraform mencoba meluncurkan database Cloud SQL sebelum jalur *VPC Network Peering* selesai terbentuk sepenuhnya.
> * **Solusi:** Menambahkan atribut `depends_on = [var.private_vpc_connection_id]` pada blok konfigurasi resource Cloud SQL untuk memaksa Terraform menunggu selesainya koneksi jaringan privat.

> **2. Kesalahan Format Identitas Kunci Enkripsi (CMEK IAM)**
> * **Kendala:** Proses binding izin akses gagal karena konfigurasi kunci enkripsi membutuhkan parameter *Project Number* yang bersifat numerik, bukan teks *Project ID*.
> * **Solusi:** Memanfaatkan objek data dinamis `data.google_project` bawaan Terraform untuk menarik data *Project Number* secara otomatis langsung dari konsol GCP.

---

## 💰 Analisis & Optimasi Biaya Operasional (Cost-Awareness)
Sebagai bentuk pemenuhan pilar *Cost-Awareness*, kalkulasi biaya operasional dihitung secara akurat menggunakan **GCP Pricing Calculator** untuk penempatan infrastruktur pada **Region Jakarta (`asia-southeast2`)**. Total biaya operasional sistem ini adalah **$13.46 / Bulan** (± Rp 210.000,-).

### 📊 Distribusi Pengeluaran Bulanan

[Cloud SQL MySQL] ████████████████████████████████████████ $13.03 (96.8%)

[Cloud Storage & Run] █ $0.42 (3.1%)

[Pub/Sub & Operations] $0.01 (0.1%)

### 🛠️ Strategi Optimasi Biaya yang Diterapkan:
1. **Object Lifecycle Management:** Mengonfigurasi kebijakan agar berkas log mentah berformat JSON/CSV di Cloud Storage yang telah berusia lebih dari 90 hari otomatis dihapus atau dipindahkan ke penyimpanan arsip dingin (*Coldline/Archive*) guna menekan pembengkakan biaya ruang penyimpanan.
2. **Budget Alert Control:** Menerapkan sistem batas anggaran pengaman (*Budget Alert*) di Google Billing Console sebesar **Rp 100.000,- / bulan** dengan ambang batas notifikasi darurat pada tingkat penggunaan 50%, 90%, dan 100% yang terintegrasi ke saluran komunikasi tim.

---

## 🚀 Panduan Replikasi Infrastruktur (Quick Start)
To duplicate this infrastructure, run the following commands inside your terminal:

```bash
# 1. Masuk ke direktori infrastruktur
cd terraform

# 2. Inisialisasi provider GCP dan download dependensi modul
terraform init

# 3. Validasi kebenaran sintaks kode IaC
terraform validate

# 4. Tinjau rencana pembuatan resource cloud
terraform plan

# 5. Terapkan konfigurasi untuk meluncurkan seluruh resource ke GCP
terraform apply -auto-approve

---