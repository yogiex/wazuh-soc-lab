# Wazuh SOC Lab

Lab belajar **Wazuh** (SIEM & XDR) untuk praktik monitoring keamanan.  
Simulasi pengumpulan log dari **Sangfor NGAF**, **Web Application Firewall (WAF)**,  
**shared hosting** multi‑domain, dan **multi‑site lab universitas** — semuanya dalam satu Docker Compose.

[![Wazuh](https://img.shields.io/badge/Wazuh-4.14.5-005571?logo=wazuh)](https://wazuh.com)
[![Docker](https://img.shields.io/badge/Docker-✓-2496ED?logo=docker)](https://docs.docker.com/compose/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 🛠 Tech Stack

| Teknologi | Versi | Fungsi |
|-----------|-------|--------|
| Wazuh Manager | 4.14.5 | SIEM/XDR engine — agent management, log analysis, alerting |
| Wazuh Indexer | 4.14.5 | OpenSearch-based storage & indexing |
| Wazuh Dashboard | 4.14.5 | Kibana-based UI — visualisasi & pencarian |
| OpenSearch | 2.19.5 | Penyimpanan alert & event (managed by Wazuh Indexer) |
| OpenSearch Dashboards | 2.19.5 | Core dashboard framework |
| Apache httpd | 2.4 | Web server untuk shared hosting & multi-site containers |
| WordPress | 6.x (latest via wp-cli) | CMS dummy di setiap domain shared hosting |
| PHP | 8.x | Runtime WordPress |
| Alpine Linux | 3.21 | Base image log injector |
| Python | 3.x | Digunakan di entrypoint scripts |
| Docker Compose | ≥ 2.x | Orkestrasi multi-container |

---

## 📋 Daftar Isi

- [Tech Stack](#-tech-stack)
- [Arsitektur](#-arsitektur)
- [Struktur Folder](#-struktur-folder)
- [Persyaratan](#-persyaratan)
- [Cara Menjalankan](#-cara-menjalankan)
- [Konfigurasi & Kustomisasi](#-konfigurasi--kustomisasi)
- [Log Injector](#-log-injector)
- [Mengirim Log Uji](#-mengirim-log-uji)
- [Belajar Membaca Log](#-belajar-membaca-log)
- [Troubleshooting](#-troubleshooting)
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
    Injector["🤖 Log Injector<br/>8 attack scenarios<br/>30s cycle"]
    end

    subgraph Wazuh Stack
        Manager["Wazuh Manager<br/>(Syslog UDP receiver,<br/>TCP agent, Auth daemon)"]
        Indexer["Wazuh Indexer<br/>(OpenSearch)"]
        Dashboard["Wazuh Dashboard<br/>(Kibana-based)"]
    end

    Injector -->|File inject via docker| Shared
    Injector -->|File inject via docker| Multi
    Injector -->|Syslog UDP| Manager
    Sangfor -->|Log via syslog| Manager
    WAF -->|Log via syslog| Manager
    Shared -->|Log via agent| Manager
    Multi -->|Log via agent| Manager
    Manager -->|Alerts & events| Indexer
    Dashboard -->|Query/Visualize| Indexer
    Dashboard -->|API calls| Manager
```

**Aliran data:**

1. **Log Injector** — container Alpine yang menjalankan orchestrator shell script. Setiap 30 detik inject log NORMAL, jeda, inject log ATTACK, jeda, ulang.
2. **Injector** menginjeksi file log ke container shared-hosting & multi-site via mounted `/var/run/docker.sock` + `docker exec`.
3. **Sangfor NGAF** dan **WAF** — injector mengirim log mentah ke Wazuh Manager via **syslog UDP** (port 1514) menggunakan `nc -u`.
4. **FIM (File Integrity Monitoring)** — injector membuat/memodifikasi file di agent container untuk trigger syscheck.
5. **Container shared hosting** menjalankan Apache + Wazuh Agent (terkoneksi via **TCP 1514**). Agent membaca log dari lima domain terpisah (`domain1.ac.id` … `domain5.ac.id`).
6. **Container multi‑site lab** mensimulasikan portal `labs.ac.id` dengan lima subdomain (prosman, keamanan, jaringan, web, data). Agent membaca satu access log gabungan (virtual host membedakan lewat `vhost`).
7. Manager menganalisis log menggunakan **decoder** dan **rule** (termasuk custom decoder untuk Sangfor/WAF), menghasilkan alert.
8. Alert disimpan di **Wazuh Indexer** (OpenSearch).
9. **Wazuh Dashboard** menampilkan visualisasi dan pencarian interaktif (port **5601**).
10. **Agent auto-registration:** Agent container mendaftar otomatis ke manager via REST API pada startup — tanpa perlu `docker exec` manual.

---

## 📁 Struktur Folder

```
.
├── config/
│   ├── wazuh_indexer/                 # Konfigurasi OpenSearch indexer
│   │   └── opensearch.yml
│   ├── wazuh_indexer_ssl_certs/       # Sertifikat SSL (hasil generate)
│   ├── wazuh_manager/
│   │   ├── local_decoder.xml               # Custom decoder Sangfor/WAF
│   │   ├── local_rules.xml                 # Custom rule alerts (incl. FIM rules 100020-100024)
│   │   ├── local_internal_options.conf      # analysisd.syscollector_threads=1
│   │   ├── ossec.conf                      # Konfigurasi Manager (syslog receiver + indexer)
│   │   └── shared/
│   │       └── wordpress-hosting/
│   │           └── agent.conf              # Group config: FIM syscheck (brace expansion)
│   └── wazuh_dashboard/                    # Konfigurasi OpenSearch Dashboards
│       ├── opensearch_dashboards.yml
│       └── wazuh.yml                       # API connection (run_as: false)
├── docs/                              # Studi SOC-200 & dokumentasi
│   └── STRUKTUR-FOLDER.md
├── scripts/
│   ├── orchestrator.sh                # Main entrypoint injector
│   ├── orchestrator.conf              # Timing, scenarios, intensity
│   ├── inject-common.sh               # Library functions inject
│   └── scenarios/
│       ├── web-recon.sh               # Directory busting + path traversal
│       ├── web-sqli.sh                # SQL injection payloads
│       ├── web-xss.sh                 # Reflected XSS payloads
│       ├── web-bruteforce.sh          # wp-login brute force
│       ├── ssh-brute.sh               # SSH brute + post-exploit sudo
│       ├── sangfor-logs.sh            # Sangfor NGAF syslog UDP
│       ├── waf-logs.sh                # WAF syslog UDP
│       └── fim-webshell.sh            # Webshell file create + FIM trigger
├── docker-compose.yml                 # Orkestrasi semua service
├── Dockerfile.injector                # Image injector (Alpine + docker-cli)
├── Dockerfile.shared                  # Image shared hosting (5 domain)
├── Dockerfile.multi-site              # Image multi‑site (labs.ac.id)
├── entrypoint.sh                      # Startup script multi-site
├── entrypoint-wordpress.sh            # Startup script shared hosting (auto DB + WP)
├── register-agent.sh                  # Auto‑register agent via Wazuh API
├── setup.sh                           # Setup awal environment
├── shared-hosting.conf                # VirtualHost Apache untuk shared hosting
├── multi-site.conf                    # VirtualHost Apache untuk multi‑site
├── wazuh-agent-shared.conf            # Konfigurasi agent untuk shared hosting
├── wazuh-agent-multisite.conf         # Konfigurasi agent untuk multi‑site
├── wazuh-agent-ossec.conf             # Konfigurasi agent alternatif
└── README.md
```

---

## 🔧 Persyaratan

- **Docker Engine** ≥ 20.10
- **`docker-compose`** (standalone binary, bukan plugin `docker compose`)
- RAM minimal **6 GB** (direkomendasikan 8 GB)
- Port yang tersedia:
  - `5601` → Wazuh Dashboard (HTTPS)
  - `1514/udp` → Syslog receiver
  - `1514/tcp` → Agent connection (secure)
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

Sertifikat SSL sudah tersedia di `config/wazuh_indexer_ssl_certs/`.  
Untuk membuat ulang dari awal:

```bash
cd /tmp
git clone https://github.com/wazuh/wazuh-docker.git -b v4.14.5
cd wazuh-docker/single-node

docker-compose -f generate-indexer-certs.yml run --rm generator

# Salin ke folder proyek
cp -r config/wazuh_indexer_ssl_certs/* \
    ~/Documents/code/sec/wazuh-belajar/config/wazuh_indexer_ssl_certs/
```

### 3. Bangun dan jalankan lab

```bash
cd ~/Documents/code/sec/wazuh-belajar   # atau path repo
docker-compose up -d --build
```

Tunggu beberapa menit hingga semua container **healthy** (`docker-compose ps`).

### 4. Akses layanan

- **Wazuh Dashboard**: [https://localhost:5601](https://localhost:5601)
  Username: `kibanaserver` / Password: `kibanaserver`
  > Jika dashboard menampilkan **"No agents were added to the manager"** meski agent sudah terdaftar,
  > pastikan `run_as: false` di `config/wazuh_dashboard/wazuh.yml`, lalu clear browser cookies
  > dan reload halaman. Lihat [Troubleshooting](#-troubleshooting).

- **Shared Hosting** (5 domain WordPress):
  Tambahkan domain ke `/etc/hosts`:
  ```bash
  echo '127.0.0.1 domain1.ac.id domain2.ac.id domain3.ac.id domain4.ac.id domain5.ac.id' | sudo tee -a /etc/hosts
  ```
  Buka di browser: `http://domain1.ac.id:7070` (s.d. domain5)
  > Akses via `curl`:
  > ```bash
  > curl -H "Host: domain1.ac.id" http://localhost:7070
  > ```
  >
  > **WordPress admin:** `http://domain1.ac.id:7070/wp-admin`
  > User: `admin` / Pass: `mBatzc2*WyqVAx%@FA`
  > > ⚠️ Injector akan overwrite `wp-config.php` sebagai simulasi webshell — FIM rule 100021 akan trigger.

- **Multi‑site Lab** (labs.ac.id & subdomain):
  ```bash
  curl -H "Host: labs.ac.id" http://localhost:7071
  curl -H "Host: prosman.labs.ac.id" http://localhost:7071
  curl -H "Host: keamanan.labs.ac.id" http://localhost:7071
  # … s.d. data.labs.ac.id
  ```

---

## ⚙️ Konfigurasi & Kustomisasi

### Custom Decoder & Rule (Sangfor NGAF & WAF)

Dua decoder sudah tersedia di `config/wazuh_manager/local_decoder.xml`:

| Decoder | Pemetaan Field |
|---------|---------------|
| **Sangfor NGAF** | `devid`, `srcip`, `dstip`, `ngaf_action`, `policy`, `type`, `severity` |
| **WAF** | `srcip`, `dstip`, `rule`, `method`, `uri`, `waf_status` |

10 rules siap pakai di `local_rules.xml` (ID 100002–100005 Sangfor, 100010–100015 WAF).

### Menambah Custom Decoder & Rule Baru

Edit file di `config/wazuh_manager/`:

1. **`local_decoder.xml`** – definisikan cara mem-parse log mentah.
2. **`local_rules.xml`** – tentukan rule alert berdasarkan field hasil parsing.

> **⚠️ Reserved words:** Jangan gunakan `action`, `status`, atau `type` sebagai `<field name>`.  
> Gunakan prefiks seperti `ngaf_action`, `waf_status`.

Setelah mengedit, restart manager:

```bash
docker-compose restart wazuh-manager
```

### Mengirim Log dari Perangkat Asli

Arahkan syslog perangkat Anda ke `<ip-host>:1514/udp` (Sangfor/WAF) atau daftarkan agent ke port `1514/tcp`.

Contoh konfigurasi Sangfor NGAF:

```
Log server: <ip-host>
Port: 1514
Protokol: UDP
Format: syslog (RFC 3164/5424)
Field: devid, src, dst, ngaf_action, policy, type, severity
```

**Agent auto-registration:**  
Container agent (`shared-hosting`, `multi-site`) otomatis mendaftar ke manager via API saat pertama kali dijalankan. Tidak perlu registrasi manual — cukup `docker-compose up -d --build`.

### Menambah Domain di Shared Hosting

1. Tambahkan direktori di `Dockerfile.shared` (loop `for i in 1 2 …` atau baris baru).
2. Tambahkan blok `<VirtualHost>` di `shared-hosting.conf`.
3. Tambahkan dua blok `<localfile>` (access dan error) di `wazuh-agent-shared.conf`.
4. Rebuild:
   ```bash
   docker-compose up -d --build shared-hosting
   ```

### Menambah Subdomain di Multi‑site Lab

1. Buat folder baru di dalam `Dockerfile.multi-site` (misal `/home/labs.ac.id/public_html/iot`).
2. Tambahkan `<VirtualHost>` di `multi-site.conf`.
3. Karena semua subdomain menulis ke file log yang sama, **tidak perlu mengubah agent config**.
4. Rebuild:
   ```bash
   docker-compose up -d --build multi-site
   ```

---

## 🤖 Log Injector

Container **injector** otomatis menghasilkan log uji secara periodik — tanpa perlu menulis command manual.

### Arsitektur

| Komponen | Fungsi |
|----------|--------|
| `orchestrator.sh` | Main loop: NORMAL → sleep 30s → ATTACK → sleep 30s → repeat |
| `orchestrator.conf` | Konfigurasi timing, scenario enabled, intensity |
| `inject-common.sh` | Library: `inject_apache`, `inject_auth`, `inject_syslog`, `inject_file` |
| `scenarios/*.sh` | 8 scenario scripts untuk berbagai tipe serangan |

### Metode Injection

| Metode | Target | Mekanisme |
|--------|--------|-----------|
| **File append** | Apache log & auth.log agent | `docker exec <agent> sh -c "echo ... >> file"` |
| **Syslog UDP** | Wazuh Manager port 1514 | `nc -u <manager> 1514` |
| **File create/mod** | FIM trigger di agent | `docker exec <agent> touch/echo` |

### Konfigurasi

Edit `scripts/orchestrator.conf`:

```bash
BASELINE_INTERVAL=30      # Durasi fase NORMAL (detik)
ATTACK_INTERVAL=30        # Durasi fase ATTACK (detik)
CYCLE_MODE="sequential"   # sequential / random
INTENSITY="medium"        # low / medium / high
ENABLED_SCENARIOS="web-recon web-sqli ..."  # Daftar scenario aktif
NORMAL_INJECT="yes"       # Inject traffic normal juga
```

### Scenario Overview

| Scenario | Tipe Log | Tujuan |
|----------|----------|--------|
| `web-recon` | Apache access | Directory busting, path traversal |
| `web-sqli` | Apache access | SQL injection pattern |
| `web-xss` | Apache access | Reflected XSS |
| `web-bruteforce` | Apache access | wp-login brute force |
| `ssh-brute` | auth.log | SSH brute + sudo post-exploit |
| `sangfor-logs` | Syslog UDP | Sangfor NGAF security log |
| `waf-logs` | Syslog UDP | WAF block log |
| `fim-webshell` | File create | Webshell FIM detection |
| `google-site-verification` | File create + Apache access | Googlebot verification + crawl simulation |
| `web-scan` | Apache access | Automated scanner (WPScan, Nikto, WhatWeb, Gobuster, Nuclei) |
| `info-disclosure` | Apache access | Backup file, config disclosure, DB dump, PHP info probes |

---

## 📨 Mengirim Log Uji

Gunakan `netcat` untuk mengirim log syslog tiruan dari terminal:

```bash
# Log Sangfor NGAF
echo '<134>2026-06-21T10:15:30Z SangforNGAF devid=NGAF-01 src=192.168.1.100 dst=10.0.0.5 ngaf_action=blocked policy="Block High Risk" type=web-attack severity=high' | nc -u -w0 localhost 1514

# Log WAF
echo '<131>2026-06-21T10:16:05Z WAF-01 src=172.16.0.10 dst=203.0.113.50 rule=SQLi method=GET uri=/login?id=1%27%20OR%20%271%27%3D%271 waf_status=403' | nc -u -w0 localhost 1514
```

> **Catatan:** Field `action` di Sangfor → `ngaf_action`, field `status` di WAF → `waf_status`  
> karena `action`, `status`, dan `type` adalah reserved word di Wazuh rules.

Log ini akan muncul di Dashboard setelah beberapa detik.

---

## 📖 Belajar Membaca Log

1. Buka **Wazuh Dashboard** → **Discover** (index pattern `wazuh-alerts-*`).
2. Cari event berdasarkan:
   - **Agent**: `agent.name : "shared-hosting"` atau `agent.name : "multi-site"`
   - **Syslog langsung**: ketik `manager.name : "wazuh-manager"` (log Sangfor/WAF tanpa agent)
   - **Domain/Subdomain**: `data.vhost : "domain1.ac.id"` atau `data.vhost : "prosman.labs.ac.id"`
3. Lihat field hasil parsing di `data.*`:
   - **Sangfor NGAF**: `data.ngaf_action`, `data.srcip`, `data.dstip`, `data.policy`, `data.severity`
   - **WAF**: `data.waf_status`, `data.srcip`, `data.dstip`, `data.rule`, `data.method`, `data.uri`
4. Buat visualisasi: grafik serangan per domain, top attacker IP, traffic per subdomain, dll.

Contoh decoder Sangfor NGAF & WAF sudah tersedia di `local_decoder.xml`, bisa langsung digunakan.

## 🔧 Troubleshooting

### Dashboard menampilkan "No agents were added to the manager"

**Penyebab:** Token API yang disimpan di browser memiliki `run_as: true` dengan `rbac_roles: []` (tanpa izin).

**Solusi:**

1. Edit `config/wazuh_dashboard/wazuh.yml`, pastikan `run_as: false`.
2. Copy file ke container:
   ```bash
   docker-compose cp config/wazuh_dashboard/wazuh.yml wazuh-dashboard:/usr/share/wazuh-dashboard/data/wazuh/config/wazuh.yml
   ```
3. Restart dashboard:
   ```bash
   docker-compose restart wazuh-dashboard
   ```
4. Clear browser cookies untuk domain `localhost:5601`, reload halaman.

### Website WordPress mengembalikan 403 Forbidden

**Penyebab:** Apache default config memiliki `<Directory />` dengan `Require all denied`, sementara DocumentRoot mengarah ke `/home/domain*.ac.id/public_html` tanpa `<Directory>` block yang mengizinkan akses.

**Solusi:** Blok `<Directory /home/>` sudah ditambahkan di `shared-hosting.conf`:
```apache
<Directory /home/>
    Options Indexes FollowSymLinks
    AllowOverride All
    Require all granted
</Directory>
```
Setelah edit, rebuild container:
```bash
docker-compose up -d --build shared-hosting
```

### FIM rules tidak trigger (webshell / file tamper)

**Penyebab:** FIM syscheck dikonfigurasi via **group** (`wordpress-hosting`), bukan di agent local config.

**Solusi:**

1. Assign agent `shared-hosting` ke group `wordpress-hosting`:
   ```bash
   TOKEN=$(curl -sk -u wazuh:MyS3cur3P@ss! -X POST \
     "https://localhost:55000/security/user/authenticate" | \
     python3 -c "import sys,json; print(json.load(sys.stdin)['data']['token'])")

   curl -sk -X PUT "https://localhost:55000/agents/002/group/wordpress-hosting" \
     -H "Authorization: Bearer $TOKEN"
   ```
2. Agent akan pull group config dalam beberapa menit, atau restart agent:
   ```bash
   docker-compose restart shared-hosting
   ```
3. Verifikasi agent tergabung di grup:
   ```bash
   curl -sk "https://localhost:55000/agents/002?pretty=true" \
     -H "Authorization: Bearer $TOKEN" | grep group
   ```

Log FIM akan muncul dengan rule ID:
- **100020** (level 12) — New .php file (webshell)
- **100021** (level 10) — wp-config.php modified
- **100022** (level 10) — .htaccess modified
- **100023** (level 7) — PHP file modified
- **100024** (level 5) — File deleted

### Syscollector / Inventory data tidak muncul di Dashboard

**Penyebab:** Dua hal yang perlu dicek:
- Manager `ossec.conf` harus punya blok `<indexer>` agar Inventory Harvester bisa mengirim data ke OpenSearch.
- `analysisd.syscollector_threads` harus ≥ 1 di `local_internal_options.conf`.

**Solusi:** File-file berikut sudah dikonfigurasi dengan benar:
- `config/wazuh_manager/ossec.conf` — blok `<indexer>` mengarah ke `https://wazuh-indexer:9200`.
- `config/wazuh_manager/local_internal_options.conf` — berisi `analysisd.syscollector_threads=1`.
- `wazuh-agent-shared.conf` / `wazuh-agent-multisite.conf` — menggunakan `<wodle name="syscollector">` (bukan `inventory` yang deprecated).

---

## 📄 Lisensi

Proyek ini dilisensikan di bawah [MIT License](LICENSE) — bebas digunakan, dimodifikasi, dan didistribusikan.

---

**Selamat belajar!**
Jika ada pertanyaan, silakan buka [Issues](https://github.com/yogiex/wazuh-soc-lab/issues) atau kontak penulis.

```

```
