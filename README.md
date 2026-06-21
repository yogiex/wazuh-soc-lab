# Wazuh SOC Lab

Lab belajar **Wazuh** (SIEM & XDR) untuk praktik monitoring keamanan.  
Simulasi pengumpulan log dari **Sangfor NGAF**, **Web Application Firewall (WAF)**,  
**shared hosting** multi‑domain, dan **multi‑site lab universitas** — semuanya dalam satu Docker Compose.

[![Wazuh](https://img.shields.io/badge/Wazuh-4.9.0-005571?logo=wazuh)](https://wazuh.com)
[![Docker](https://img.shields.io/badge/Docker-✓-2496ED?logo=docker)](https://docs.docker.com/compose/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 📋 Daftar Isi

- [Arsitektur](#-arsitektur)
- [Struktur Folder](#-struktur-folder)
- [Persyaratan](#-persyaratan)
- [Cara Menjalankan](#-cara-menjalankan)
- [Konfigurasi & Kustomisasi](#-konfigurasi--kustomisasi)
- [Mengirim Log Uji](#-mengirim-log-uji)
- [Belajar Membaca Log](#-belajar-membaca-log)
- [Lisensi](#-lisensi)

---

## 🏗 Arsitektur

```mermaid
graph TB
    subgraph Sumber Log
        Sangfor["🔥 Sangfor NGAF<br/>Syslog UDP 1514"]
        WAF["🛡️ WAF<br/>Syslog UDP 1514"]
        Shared["🌐 Shared Hosting<br/>5 domain terpisah<br/>Agent: wazuh-agent-shared"]
        Multi["🏫 Multi-site Lab<br/>labs.ac.id + 5 subdomain<br/>Agent: wazuh-agent-multisite"]
    end

    subgraph Wazuh Stack
        Manager["Wazuh Manager<br/>(Syslog receiver,<br/>Analysis Engine)"]
        Indexer["Wazuh Indexer<br/>(OpenSearch)"]
        Dashboard["Wazuh Dashboard<br/>(Kibana-based)"]
    end

    Sangfor -->|Log via syslog| Manager
    WAF -->|Log via syslog| Manager
    Shared -->|Log via agent| Manager
    Multi -->|Log via agent| Manager
    Manager -->|Alerts & events| Indexer
    Dashboard -->|Query/Visualize| Indexer
    Dashboard -->|API calls| Manager
```

**Aliran data:**

1. **Sangfor NGAF** dan **WAF** mengirim log mentah ke Wazuh Manager melalui **syslog UDP** (port 1514).
2. **Container shared hosting** menjalankan Apache + Wazuh Agent. Agent membaca log dari lima domain terpisah (`domain1.ac.id` … `domain5.ac.id`).
3. **Container multi‑site lab** mensimulasikan portal `labs.ac.id` dengan lima subdomain (prosman, keamanan, jaringan, web, data). Agent membaca satu access log gabungan (virtual host membedakan lewat `vhost`).
4. Manager menganalisis log menggunakan **decoder** dan **rule** (termasuk custom decoder untuk Sangfor/WAF), menghasilkan alert.
5. Alert disimpan di **Wazuh Indexer** (OpenSearch).
6. **Wazuh Dashboard** menampilkan visualisasi dan pencarian interaktif.

---

## 📁 Struktur Folder

```
.
├── config/
│   ├── wazuh_indexer_ssl_certs/       # Sertifikat SSL (hasil generate)
│   └── wazuh_manager/
│       ├── local_decoder.xml          # Custom decoder Sangfor/WAF
│       ├── local_rules.xml            # Custom rule alerts
│       └── ossec.conf                 # Konfigurasi Manager (syslog receiver)
├── docker-compose.yml                 # Orkestrasi semua service
├── Dockerfile.shared                  # Image shared hosting (5 domain)
├── Dockerfile.multi-site              # Image multi‑site (labs.ac.id)
├── entrypoint.sh                      # Startup script (dipakai kedua container)
├── shared-hosting.conf                # VirtualHost Apache untuk shared hosting
├── multi-site.conf                    # VirtualHost Apache untuk multi‑site
├── wazuh-agent-shared.conf            # Konfigurasi agent untuk shared hosting
├── wazuh-agent-multisite.conf         # Konfigurasi agent untuk multi‑site
└── README.md
```

---

## 🔧 Persyaratan

- **Docker Engine** ≥ 20.10
- **Docker Compose** ≥ v2 (plugin `docker compose`)
- RAM minimal **6 GB** (direkomendasikan 8 GB)
- Port yang tersedia:
  - `443` → Wazuh Dashboard
  - `1514/udp` → Syslog receiver
  - `7070` → Shared hosting (multi‑domain)
  - `7071` → Multi‑site lab

---

## 🚀 Cara Menjalankan

### 1. Clone repository

```bash
git clone https://github.com/yogiex/wazuh-soc-lab.git
cd wazuh-soc-lab
```

### 2. Generate Sertifikat SSL

Wazuh Indexer membutuhkan sertifikat untuk komunikasi terenkripsi.

```bash
cd /tmp
git clone https://github.com/wazuh/wazuh-docker.git -b v4.9.0
cd wazuh-docker/single-node

docker compose -f generate-indexer-certs.yml run --rm generator

# Salin ke folder proyek
cp -r config/wazuh_indexer_ssl_certs/* \
    ~/Documents/code/sec/wazuh-belajar/config/wazuh_indexer_ssl_certs/
```

### 3. Bangun dan jalankan lab

```bash
cd ~/Documents/code/sec/wazuh-belajar   # atau path repo
docker compose up -d --build
```

Tunggu beberapa menit hingga semua container **healthy** (`docker compose ps`).

### 4. Akses layanan

- **Wazuh Dashboard**: [https://localhost](https://localhost)
  Username: `kibanaserver` / Password: `kibanaserver`

- **Shared Hosting** (5 domain terpisah):
  Akses via `curl` dengan header `Host`:

  ```bash
  curl -H "Host: domain1.ac.id" http://localhost:7070
  curl -H "Host: domain2.ac.id" http://localhost:7070
  # … s.d. domain5.ac.id
  ```

- **Multi‑site Lab** (labs.ac.id & subdomain):
  ```bash
  curl -H "Host: labs.ac.id" http://localhost:7071
  curl -H "Host: prosman.labs.ac.id" http://localhost:7071
  curl -H "Host: keamanan.labs.ac.id" http://localhost:7071
  # … s.d. data.labs.ac.id
  ```

---

## ⚙️ Konfigurasi & Kustomisasi

### Menambah Custom Decoder & Rule

Edit file di `config/wazuh_manager/`:

1. **`local_decoder.xml`** – definisikan cara mem-parse log mentah.
2. **`local_rules.xml`** – tentukan rule alert berdasarkan field hasil parsing.

Setelah mengedit, restart manager:

```bash
docker compose restart wazuh-manager
```

### Mengirim Log dari Perangkat Asli

Arahkan syslog perangkat Anda ke `<ip-host>:1514/udp`.
Contoh konfigurasi Sangfor NGAF:

```
Log server: <ip-host>
Port: 1514
Protokol: UDP
Format: syslog (RFC 3164/5424)
```

### Menambah Domain di Shared Hosting

1. Tambahkan direktori di `Dockerfile.shared` (loop `for i in 1 2 …` atau baris baru).
2. Tambahkan blok `<VirtualHost>` di `shared-hosting.conf`.
3. Tambahkan dua blok `<localfile>` (access dan error) di `wazuh-agent-shared.conf`.
4. Rebuild:
   ```bash
   docker compose up -d --build shared-hosting
   ```

### Menambah Subdomain di Multi‑site Lab

1. Buat folder baru di dalam `Dockerfile.multi-site` (misal `/home/labs.ac.id/public_html/iot`).
2. Tambahkan `<VirtualHost>` di `multi-site.conf`.
3. Karena semua subdomain menulis ke file log yang sama, **tidak perlu mengubah agent config**.
4. Rebuild:
   ```bash
   docker compose up -d --build multi-site
   ```

---

## 📨 Mengirim Log Uji

Gunakan `netcat` untuk mengirim log syslog tiruan dari terminal:

```bash
# Log Sangfor NGAF
echo '<134>2026-06-21T10:15:30Z SangforNGAF devid=NGAF-01 src=192.168.1.100 dst=10.0.0.5 action=blocked policy="Block High Risk" type=web-attack severity=high' | nc -u -w0 localhost 1514

# Log WAF
echo '<131>2026-06-21T10:16:05Z WAF-01 src=172.16.0.10 dst=203.0.113.50 rule=SQLi method=GET uri=/login?id=1%27%20OR%20%271%27%3D%271 status=403' | nc -u -w0 localhost 1514
```

Log ini akan muncul di Dashboard setelah beberapa detik.

---

## 📖 Belajar Membaca Log

1. Buka **Wazuh Dashboard** → **Discover** (index pattern `wazuh-alerts-*`).
2. Cari event berdasarkan:
   - **Agent**: `agent.name : "shared-hosting"` atau `agent.name : "multi-site"`
   - **Domain/Subdomain**: `data.vhost : "domain1.ac.id"` atau `data.vhost : "prosman.labs.ac.id"`
3. Lihat field hasil parsing di `data.*` (misal `data.srcip`, `data.action`).
4. Buat visualisasi: grafik serangan per domain, top attacker IP, traffic per subdomain, dll.

Contoh decoder Sangfor NGAF sudah tersedia di `local_decoder.xml`, bisa langsung digunakan.

---

## 📄 Lisensi

Proyek ini dilisensikan di bawah [MIT License](LICENSE) — bebas digunakan, dimodifikasi, dan didistribusikan.

---

**Selamat belajar!**
Jika ada pertanyaan, silakan buka [Issues](https://github.com/yogiex/wazuh-soc-lab/issues) atau kontak penulis.

```

```
