#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/orchestrator.conf"
source "$SCRIPT_DIR/inject-common.sh"

GOOGLEBOT_UA="Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
SHARED_DOMAINS=("domain1.ac.id" "domain2.ac.id" "domain3.ac.id" "domain4.ac.id" "domain5.ac.id")
COUNT=$(get_attack_lines)
VERIFICATION_ID="google$(printf '%x' $((RANDOM % 0xFFFFFFF)))"

# Shared-hosting: inject verification file + Googlebot access
for dom in "${SHARED_DOMAINS[@]}"; do
    WEB_ROOT="/home/${dom}/public_html"
    inject_file_write "$AGENTS_SHARED" "${WEB_ROOT}/${VERIFICATION_ID}.html" \
        "google-site-verification: ${VERIFICATION_ID}.html"
    inject_apache_access "$AGENTS_SHARED" "$dom" "66.249.66.$((RANDOM % 255))" \
        "GET" "/${VERIFICATION_ID}.html" "200" "$GOOGLEBOT_UA"
done

# Multi-site: inject verification file + Googlebot access
MS_ROOT="/home/labs.ac.id/public_html"
inject_file_write "$AGENTS_MULTI" "${MS_ROOT}/${VERIFICATION_ID}.html" \
    "google-site-verification: ${VERIFICATION_ID}.html"
inject_apache_access "$AGENTS_MULTI" "labs.ac.id" "66.249.66.$((RANDOM % 255))" \
    "GET" "/${VERIFICATION_ID}.html" "200" "$GOOGLEBOT_UA"

# Additional Googlebot normal crawl traffic
for ((i=0; i<COUNT; i++)); do
    dom="${SHARED_DOMAINS[$((RANDOM % ${#SHARED_DOMAINS[@]}))]}"
    case $((RANDOM % 6)) in
        0) uri="/" ;;
        1) uri="/wp-content/themes/style.css" ;;
        2) uri="/wp-content/themes/script.js" ;;
        3) uri="/wp-content/uploads/img${RANDOM}.jpg" ;;
        4) uri="/wp-includes/js/jquery.js" ;;
        5) uri="/robots.txt" ;;
    esac
    inject_apache_access "$AGENTS_SHARED" "$dom" "66.249.66.$((RANDOM % 255))" \
        "GET" "$uri" "200" "$GOOGLEBOT_UA"
done

log_orch "scenario=google-site-verification id=${VERIFICATION_ID} lines=$((COUNT + ${#SHARED_DOMAINS[@]} + 2))"
