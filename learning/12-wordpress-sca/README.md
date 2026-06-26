# 12 — WordPress Security Assessment dengan Wazuh SCA

## 1. Apa itu Wazuh SCA?

**SCA (Security Configuration Assessment)** adalah modul Wazuh yang melakukan
scan terhadap konfigurasi endpoint untuk mendeteksi **misconfigurations**,
**default settings yang tidak aman**, dan **penyimpangan dari security baseline**.

### SCA vs FIM vs Rules — Jangan Tertukar

| Modul | Fungsi | Cara Kerja | Contoh |
|-------|--------|------------|--------|
| **SCA** | Audit konfigurasi | Policy-based scan → pass/fail | "File permission wp-config.php harus 440" |
| **FIM** | Monitor perubahan file | Real-time event → alert | "index.php berubah (siapa? kapan?)" |
| **Rules** | Deteksi serangan | Log analysis → alert | "SQL Injection terdeteksi di URI" |

```
SCA  = "Apa yang salah dengan konfigurasi?"
FIM  = "Apa yang berubah di filesystem?"
Rules = "Apa yang sedang terjadi sekarang?"
```

### Siklus SCA

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│ Policy File │────>│ Agent Scan   │────>│ Dashboard    │
│ (YAML)      │     │ (periodik)   │     │ (pass/fail)  │
└─────────────┘     └──────────────┘     └──────────────┘
       │                    │                     │
       │ define checks      │ jalankan command    │ tampilkan hasil
       │ via rule           │ bandingkan output   │ + rekomendasi
       │                    │ dengan regex         │ remediasi
```

---

## 2. 8 WordPress Misconfigurations (Menurut Wazuh + OWASP)

Berdasarkan [WordPress Hardening Guide](https://wordpress.org/support/article/hardening-wordpress/)
dan [OWASP Top 10](https://owasp.org/Top10/), ada 8 risiko utama:

### 2.1 Vulnerable/Outdated Components — [OWASP A06:2021](https://owasp.org/Top10/A06_2021-Vulnerable_and_Outdated_Components/)

Plugin, theme, atau WordPress core yang usang memiliki CVE yang sudah publik.
Penyerang tinggal match versi → exploit.

**Contoh nyata di lab:** WordPress di-download `latest.tar.gz` saat build,
tapi tidak pernah di-update. Plugin default Akismet + Hello Dolly tidak dihapus.

### 2.2 File/Folder Permission Salah

| Path | Seharusnya | Akibat Salah |
|------|-----------|--------------|
| Folder (`wp-admin/`) | 755 | Bisa baca/tulis file oleh user lain |
| File (`.htaccess`) | 644 | Bisa baca/menulis konfigurasi redirect |
| `wp-config.php` | 440 | Bocor DB credentials |

### 2.3 Default Database Prefix `wp_`

Banyak SQLi payload yang asumsi prefix `wp_`:

```sql
SELECT * FROM wp_users WHERE user_login = 'admin' -- exploit mengandalkan wp_
```

Ganti ke prefix random (misal `x7k9_`) saat instalasi.

### 2.4 Easily Guessed Usernames

`admin`, `administrator`, `webmaster` — target utama brute force.
Cek user di lab:

```bash
curl -s https://domain1.ac.id/wp-json/wp/v2/users | jq '.[].name'
# Kalau muncul "admin" → FAIL
```

### 2.5 WP_DEBUG Enabled

```php
define('WP_DEBUG', true);  // JANGAN di production!
```

Debug bisa nampilin **stack trace**, **SQL error**, **file path** — informasi
berharga untuk attacker.

### 2.6 Directory Browsing Enabled

```apache
Options +Indexes  // JANGAN!
```

Coba akses `https://domain.ac.id/wp-content/uploads/` — kalau muncul daftar file → FAIL.

**Di lab:** `shared-hosting.conf` baris 2: `Options Indexes FollowSymLinks`
→ **ini menyebabkan directory listing aktif.**

### 2.7 Backup Files di Webroot

```bash
# Contoh: admin membuat backup sebelum edit wp-config.php
cp wp-config.php wp-config.php.bak  # BERBAHAYA!
# File .bak tidak dieksekusi PHP → bisa dibaca sebagai text
```

### 2.8 Tidak Ada Security/Firewall Plugin

No Wordfence, Sucuri, Defender, atau All-in-One WP Security.

> **Ini adalah alasan utama SEO Cloaking sukses terjadi.**
> Security plugin bisa mendeteksi perubahan `index.php`, brute force,
> dan file anomali.

---

## 3. 11 SCA Checks — Breakdown Lengkap

Berikut 11 checks dari policy `custom_wordpress_policy.yml` (artikel Wazuh).
Setiap check akan kita bedah: command, regex, interpretasi.

### Check 100000 — WordPress Version Update

```yaml
- id: 100000
  title: "WordPress version is up to date"
  command: wp core check-update --path=<dir>
  pass: output contains "WordPress is at the latest version"
  fail: output contains version number (needs update)
```

**Cek manual di lab:**
```bash
sudo docker exec shared-hosting wp core check-update \
  --path=/home/domain1.ac.id/public_html --allow-root
```

### Check 100001 — .htaccess Permission

```yaml
- id: 100001
  title: ".htaccess file permissions set to 644"
  command: stat -c '%a' <dir>/.htaccess
  pass: "644"
  fail: anything else (600, 640, 755, etc.)
```

### Check 100002 — WP_DEBUG Disabled

```yaml
- id: 100002
  title: "WordPress debugging is turned off"
  command: wp config list WP_DEBUG --path=<dir>
  pass: output != "true" or "1"
  fail: output == "true" or "1"
```

**Catatan:** Di `wp-config.php` default WP, `WP_DEBUG` tidak didefinisikan
→ berarti `false` secara default → **PASS**.

### Check 100003 — No Backup Files

```yaml
- id: 100003
  title: "No backup files in root directory"
  command: ls -la <dir>
  pass: no files with .zip .back .backup .bak .old .previous .sql
  fail: any file with those extensions found
```

**Di lab:** Scenario `fim-webshell` membuat `shell{1,2,3}.php`
→ SCA ini tidak akan trigger karena ekstensi `.php`.
Tapi jika ada `wp-config.php.bak` → FAIL.

### Check 100004 — No Common Admin Usernames

```yaml
- id: 100004
  title: "Common admin account names not used"
  command: wp user list --field=user_login
  pass: no output matching admin|administrator|backup|webmaster
  fail: any of those usernames exist
```

**Di lab:** WordPress fresh install → user `admin` ada → **FAIL**.

### Check 100005 — Directory Browsing Disabled

```yaml
- id: 100005
  title: "Directory browsing is disabled"
  command: cat <dir>/.htaccess
  pass: contains "Options All -Indexes"
  fail: Options -Indexes tidak ada di .htaccess
```

**Di lab:** Tidak ada `.htaccess` custom → **FAIL**.
Apache config `shared-hosting.conf` malah mengaktifkan Indexes.

### Check 100006 — Folder Permissions 755

```yaml
- id: 100006
  title: "WordPress folder permissions set to 755"
  rules:
    - stat -c '%a' <dir>/wp-admin             === "755"
    - stat -c '%a' <dir>/wp-includes           === "755"
    - stat -c '%a' <dir>/wp-content            === "755"
    - stat -c '%a' <dir>/wp-content/plugins    === "755"
    - stat -c '%a' <dir>/wp-content/themes     === "755"
  pass: all five === "755"
  fail: any != "755"
```

### Check 100007 — No Outdated Plugins

```yaml
- id: 100007
  title: "No out of date plugins"
  command: wp plugin list --field=update
  pass: empty output (no plugins need update)
  fail: output contains "available"
```

### Check 100008 — No Outdated Themes

```yaml
- id: 100008
  title: "No out of date themes"
  command: wp theme list --field=update
  pass: empty output
  fail: output contains "available"
```

### Check 100009 — Security Plugin Installed & Active

```yaml
- id: 100009
  title: "Security plugin is installed and active"
  command: wp plugin is-active wordfence
  pass: exit code 0 (plugin active)
  fail: exit code != 0
```

**Di lab:** Tidak ada security plugin → **FAIL**.

### Check 100010 — Database Prefix Changed

```yaml
- id: 100010
  title: "Default WordPress database prefix is changed"
  command: wp db prefix
  pass: output != "wp_"
  fail: output == "wp_"
```

**Di lab:** Default `wp_` → **FAIL**.

---

## 4. Deploy SCA Policy — Step by Step

### 4.1 Buat Policy File

Policy file sudah tersedia di:
`config/wazuh_manager/shared/wordpress-hosting/sca/wordpress_hardening.yml`

Total **13 SCA checks** termasuk 3 tambahan untuk deteksi SEO Cloaking:
- `100011` — Cek apakah `index.php` mengandung cloaking code
- `100012` — Cek apakah `wp-config.php` mengandung backdoor eval
- `100013` — Cek apakah file `security.php` ada

### 4.2 Deploy ke Agent

Ada 2 cara deploy:

**Cara A — Via agent group config (recommended):**

```bash
# 1. Copy policy ke container
sudo docker cp config/wazuh_manager/shared/wordpress-hosting/sca/wordpress_hardening.yml \
  wazuh-manager:/var/ossec/etc/shared/wordpress-hosting/sca/wordpress_hardening.yml

# 2. Update agent.conf — tambah SCA block
# config/wazuh_manager/shared/wordpress-hosting/agent.conf
```

**Cara B — Manual di endpoint:**

```bash
# 1. Masuk ke container
sudo docker exec -it shared-hosting bash

# 2. Buat direktori SCA
mkdir -p /home/local_sca_policies
chown wazuh:wazuh /home/local_sca_policies

# 3. Copy policy
# (dari host via docker cp dulu)

# 4. Update ossec.conf agent
# <sca>
#   <policies>
#     <policy>/home/local_sca_policies/wordpress_hardening.yml</policy>
#   </policies>
# </sca>

# 5. Restart agent
systemctl restart wazuh-agent
```

### 4.3 Lihat Hasil di Dashboard

Setelah agent restart dan SCA scan selesai (~5-10 menit):

**Wazuh Dashboard → Security Configuration Assessment:**
- Lihat policy `WordPress Hardening Policy`
- Lihat status **Pass / Fail** per check
- Klik check → lihat remediation

**Dev Tools — Query SCA events:**
```
GET wazuh-alerts-*/_search
{
  "query": {
    "bool": {
      "filter": [
        { "term": { "rule.id": "516" } },
        { "prefix": { "data.title.keyword": "WordPress hardening" } }
      ]
    }
  }
}
```

---

## 5. Mapping SCA Checks ke Kondisi Lab Saat Ini

| ID | Check | Status Lab | Keterangan |
|----|-------|------------|------------|
| 100000 | WP version update | **⚠️ UNCERTAIN** | Tergantung kapan terakhir build |
| 100001 | .htaccess permission 644 | **✅ PASS** | File belum dibuat → command gagal → tidak fail |
| 100002 | WP_DEBUG disabled | **✅ PASS** | Default WP = false |
| 100003 | No backup files | **⚠️ WARNING** | `shell.php` di uploads — file .php, bukan backup |
| 100004 | No common admin | **❌ FAIL** | Default WP user = `admin` |
| 100005 | Directory browsing | **❌ FAIL** | `Options Indexes` aktif di shared-hosting.conf |
| 100006 | Folder permissions 755 | **⚠️ UNCERTAIN** | Tergantung permission dari Docker build |
| 100007 | No outdated plugins | **⚠️ WARNING** | Akismet + Hello Dilly tidak diupdate |
| 100008 | No outdated themes | **✅ PASS** | Twenty Twenty-Four default |
| 100009 | Security plugin | **❌ FAIL** | Wordfence tidak terinstall |
| 100010 | DB prefix `wp_` | **❌ FAIL** | Default `wp_` |

### Implikasi

Dari 11 checks, lab memiliki minimal **3 FAIL** dan **2 UNCERTAIN** — ini
realistis menggambarkan kondisi shared hosting di lapangan yang tidak
dihardening.

---

## 6. Praktikum

### Tugas 1: Verifikasi Manual

Jalankan di container **shared-hosting**:

```bash
#!/bin/bash
# Verifikasi SCA checks manual
DOMAIN="domain1.ac.id"
DIR="/home/${DOMAIN}/public_html"

echo "=== 100000: WP Version ==="
wp core check-update --path=$DIR --allow-root 2>&1

echo "=== 100001: .htaccess permission ==="
stat -c '%a' $DIR/.htaccess 2>/dev/null || echo "FILE NOT FOUND"

echo "=== 100002: WP_DEBUG ==="
wp config list WP_DEBUG --path=$DIR --allow-root 2>&1

echo "=== 100004: Users ==="
wp user list --field=user_login --path=$DIR --allow-root

echo "=== 100005: Directory browsing ==="
curl -s -o /dev/null -w "%{http_code}" http://localhost/wp-content/plugins/

echo "=== 100006: Folder permissions ==="
stat -c '%a' $DIR/wp-admin
stat -c '%a' $DIR/wp-includes
stat -c '%a' $DIR/wp-content

echo "=== 100010: DB prefix ==="
wp db prefix --path=$DIR --allow-root
```

### Tugas 2: Remediasi

Perbaiki **3 FAIL** di lab:

```bash
# 1. Hapus user admin → buat user baru
wp user create editor editor@domain1.ac.id --role=editor \
  --user_pass=Str0ngP@ss --path=$DIR --allow-root
wp user delete 1 --allow-root --path=$DIR --reassign=2

# 2. Disable directory browsing
echo "Options All -Indexes" >> $DIR/.htaccess

# 3. Ubah DB prefix (via plugin atau manual SQL)
# Cara manual:
# 1. Dump database
# 2. Ganti wp_ → random prefix
# 3. Update wp-config.php
# 4. Import ulang
```

### Tugas 3: Buat SCA Check Baru untuk SEO Cloaking

Tambahkan check untuk mendeteksi pattern SEO Cloaking:

```yaml
- id: 100011
  title: "WordPress index.php is not modified with cloaking code"
  description: "index.php tidak boleh mengandung cloaking redirect ke security.php"
  rationale: "SEO cloaking memodifikasi index.php untuk menyajikan konten judi ke Googlebot"
  remediation: "Restore index.php dari WordPress original: wp core download --skip-content --force"
  condition: none
  rules:
    - c:grep -c 'googlebot\|security\.php\|preg_match.*UA' $wp_dirs/index.php -> r:^0$
```

---

## 7. Referensi

- [Wazuh Blog: How to perform WordPress security assessment with Wazuh](https://wazuh.com/blog/how-to-perform-wordpress-security-assessment-with-wazuh/)
- [WordPress Hardening Guide](https://wordpress.org/support/article/hardening-wordpress/)
- [OWASP Top 10 Web Application Security Risks](https://owasp.org/Top10/)
- [OWASP WordPress Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Wordpress_Security_Cheat_Sheet.html)
- [Wazuh SCA Documentation](https://documentation.wazuh.com/current/user-manual/capabilities/sec-config-assessment/index.html)
- [Studi Kasus: SEO Cloaking Parasite](../docs/CASE-STUDY-SEO-CLOAKING.md)

---

## Quick Reference Card

```
┌──────────┬──────────────────────────────────────┬──────────┬────────────────────────────┐
│ ID       │ Check                                │ Lab      │ Command                   │
├──────────┼──────────────────────────────────────┼──────────┼────────────────────────────┤
│ 100000   │ WP version up to date                │ ⚠️       │ wp core check-update      │
│ 100001   │ .htaccess permission 644             │ ✅       │ stat -c '%a' .htaccess    │
│ 100002   │ WP_DEBUG disabled                    │ ✅       │ wp config list WP_DEBUG   │
│ 100003   │ No backup files                      │ ⚠️       │ ls -la *.bak *.zip *.sql  │
│ 100004   │ No common admin usernames            │ ❌       │ wp user list              │
│ 100005   │ Directory browsing disabled          │ ❌       │ cat .htaccess | grep ...  │
│ 100006   │ Folder permissions 755               │ ⚠️       │ stat -c '%a' wp-admin/    │
│ 100007   │ No outdated plugins                  │ ⚠️       │ wp plugin list            │
│ 100008   │ No outdated themes                   │ ✅       │ wp theme list             │
│ 100009   │ Security plugin active               │ ❌       │ wp plugin is-active       │
│ 100010   │ DB prefix changed from wp_           │ ❌       │ wp db prefix              │
│ 100011   │ No SEO cloaking in index.php         │ 🔴 NEW  │ grep googlebot index.php  │
└──────────┴──────────────────────────────────────┴──────────┴────────────────────────────┘
```
