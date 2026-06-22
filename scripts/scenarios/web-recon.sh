#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/orchestrator.conf"
source "$SCRIPT_DIR/inject-common.sh"

ATTACKER_IP="10.0.0.55"
COUNT=$(get_attack_lines)

PATHS_404=(
    "/admin" "/backup" "/config.php" "/dbadmin" "/phpmyadmin"
    "/wp-admin/css/install.css" "/wp-content/plugins/akismet/akismet.php"
    "/wp-content/plugins/hello.php" "/wp-content/themes/twentyseventeen/404.php"
    "/.git/config" "/.env" "/wp-config.php~" "/wp-config.php.bak"
)

PATHS_200=(
    "/wp-admin/admin-ajax.php?doing_wp_cron"
    "/wp-admin/admin-ajax.php?action=revslider_ajax_action"
    "/wp-content/plugins/woocommerce/readme.txt"
    "/xmlrpc.php"
)

DOMAINS=("domain1.ac.id" "domain2.ac.id" "domain3.ac.id")

for ((i=0; i<COUNT; i++)); do
    dom="${DOMAINS[$((RANDOM % ${#DOMAINS[@]}))]}"
    if (( RANDOM % 4 == 0 )); then
        uri="${PATHS_200[$((RANDOM % ${#PATHS_200[@]}))]}"
        code="200"
    else
        uri="${PATHS_404[$((RANDOM % ${#PATHS_404[@]}))]}"
        code="404"
    fi
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "$uri" "$code" "Mozilla/5.0 (compatible; Nmap Scripting Engine; https://nmap.org)"
done

for ((i=0; i<3; i++)); do
    dom="${DOMAINS[$((RANDOM % ${#DOMAINS[@]}))]}"
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "/../..//etc/passwd" "400" "curl/7.88.1"
    inject_apache_error "$AGENTS_SHARED" "$dom" "error" "$ATTACKER_IP" "Invalid URI in request, declining"
done

# Multi-site
MS_PATHS=("/admin" "/backup" "/prosman/" "/keamanan/" "/jaringan/" "/.git/config" "/.env" "/../../etc/passwd")
for ((i=0; i<COUNT/3; i++)); do
    uri="${MS_PATHS[$((RANDOM % ${#MS_PATHS[@]}))]}"
    if [[ "$uri" == *"passwd"* || "$uri" == *".git"* || "$uri" == *".env"* ]]; then
        code="400"
    else
        code="404"
    fi
    inject_apache_access "$AGENTS_MULTI" "labs.ac.id" "$ATTACKER_IP" "GET" "$uri" "$code" "Mozilla/5.0 (compatible; Nmap Scripting Engine; https://nmap.org)"
done

log_orch "scenario=web-recon lines=$((COUNT + COUNT/3)) attacker=${ATTACKER_IP}"
