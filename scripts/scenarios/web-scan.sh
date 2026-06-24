#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/orchestrator.conf"
source "$SCRIPT_DIR/inject-common.sh"

ATTACKER_IP="10.0.0.200"
COUNT=$(get_attack_lines)
SHARED_DOMAINS=("domain1.ac.id" "domain2.ac.id" "domain3.ac.id")
MS_SUBDOMAINS=("labs.ac.id" "prosman.labs.ac.id" "jaringan.labs.ac.id")

# ---- WPScan: WordPress probing ----
WPATHS=(
    "/wp-json/wp/v2/users/"
    "/wp-json"
    "/?author=1"
    "/?author=2"
    "/?author=3"
    "/readme.html"
    "/license.txt"
    "/wp-includes/version.php"
    "/wp-content/plugins/akismet/akismet.php"
    "/wp-content/plugins/hello.php"
    "/wp-content/plugins/akismet/readme.txt"
    "/wp-content/themes/twentytwentyfour/style.css"
    "/wp-content/themes/twentytwentythree/style.css"
)
for ((i=0; i<COUNT/3; i++)); do
    dom="${SHARED_DOMAINS[$((RANDOM % ${#SHARED_DOMAINS[@]}))]}"
    uri="${WPATHS[$((RANDOM % ${#WPATHS[@]}))]}"
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "$uri" "200" \
        "WPScan v3.8.25 (https://wpscan.com/wordpress-scanner)"
done

# ---- Nikto: generic vulnerability scan ----
NIKTO_PATHS=(
    "/cgi-bin/test.cgi"
    "/cgi-bin/php"
    "/server-status"
    "/server-info"
    "/icons/README"
    "/phpmyadmin/"
    "/phpMyAdmin/"
    "/admin/phpmyadmin/"
    "/mysql/"
    "/admin/"
    "/test/"
    "/tmp/"
)
for ((i=0; i<COUNT/3; i++)); do
    dom="${SHARED_DOMAINS[$((RANDOM % ${#SHARED_DOMAINS[@]}))]}"
    uri="${NIKTO_PATHS[$((RANDOM % ${#NIKTO_PATHS[@]}))]}"
    code=$((RANDOM % 5 == 0 ? 200 : 404))
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "$uri" "$code" \
        "Nikto/2.5.0 (https://github.com/sullo/nikto)"
done

# ---- WhatWeb: technology fingerprint ----
WW_PATHS=(
    "/wp-content/themes/twentytwentyfour/style.css?ver=1.0"
    "/wp-content/themes/twentytwentyfour/assets/css/print.css"
    "/wp-content/themes/twentytwentythree/style.css"
    "/wp-includes/css/dist/block-library/style.min.css"
    "/wp-includes/js/wp-emoji-release.min.js"
    "/wp-content/plugins/akismet/_inc/akismet.css"
)
for ((i=0; i<COUNT/4; i++)); do
    dom="${SHARED_DOMAINS[$((RANDOM % ${#SHARED_DOMAINS[@]}))]}"
    uri="${WW_PATHS[$((RANDOM % ${#WW_PATHS[@]}))]}"
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "$uri" "200" \
        "WhatWeb/0.5.5"
done

# ---- Gobuster: directory brute force ----
GB_PATHS=(
    "/wp-admin/"
    "/wp-content/"
    "/wp-includes/"
    "/wp-content/uploads/"
    "/backup/"
    "/backups/"
    "/admin/"
    "/login/"
    "/css/"
    "/js/"
    "/images/"
    "/assets/"
    "/old/"
    "/new/"
    "/temp/"
    "/logs/"
)
for ((i=0; i<COUNT/3; i++)); do
    dom="${SHARED_DOMAINS[$((RANDOM % ${#SHARED_DOMAINS[@]}))]}"
    uri="${GB_PATHS[$((RANDOM % ${#GB_PATHS[@]}))]}"
    code=$((RANDOM % 4 == 0 ? 200 : (RANDOM % 3 == 0 ? 403 : 301)))
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "$uri" "$code" \
        "Go-http-client/2.0"
done

# ---- Nuclei: template-based pattern scan ----
NUCLEI_PATHS=(
    "/.git/config"
    "/.env"
    "/wp-config.php.bak"
    "/wp-admin/admin-ajax.php?action=wp_ajax_nopriv_test"
    "/wp-admin/admin-ajax.php?action=wp_ajax_test"
    "/index.php?p=1"
    "/index.php?page_id=1"
)
for ((i=0; i<COUNT/4; i++)); do
    dom="${SHARED_DOMAINS[$((RANDOM % ${#SHARED_DOMAINS[@]}))]}"
    uri="${NUCLEI_PATHS[$((RANDOM % ${#NUCLEI_PATHS[@]}))]}"
    code=$((RANDOM % 4 == 0 ? 200 : 404))
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "$uri" "$code" \
        "python-requests/2.31.0"
done

# ---- Multi-site scans ----
for sub in "${MS_SUBDOMAINS[@]}"; do
    for ((i=0; i<COUNT/6; i++)); do
        case $((RANDOM % 5)) in
            0) uri="/wp-json/wp/v2/users/" ; ua="WPScan v3.8.25 (https://wpscan.com)" ;;
            1) uri="/.git/config" ; ua="python-requests/2.31.0" ;;
            2) uri="/cgi-bin/test.cgi" ; ua="Nikto/2.5.0 (https://github.com/sullo/nikto)" ;;
            3) uri="/wp-admin/" ; ua="Go-http-client/2.0" ;;
            4) uri="/.env" ; ua="python-requests/2.31.0" ;;
        esac
        code=$((RANDOM % 4 == 0 ? 200 : 404))
        inject_apache_access "$AGENTS_MULTI" "$sub" "$ATTACKER_IP" "GET" "$uri" "$code" "$ua"
    done
done

log_orch "scenario=web-scan lines=$((COUNT + COUNT/6 * ${#MS_SUBDOMAINS[@]})) attacker=${ATTACKER_IP}"
