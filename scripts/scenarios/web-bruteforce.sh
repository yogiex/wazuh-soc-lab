#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/orchestrator.conf"
source "$SCRIPT_DIR/inject-common.sh"

ATTACKER_IP="10.0.0.88"
COUNT=$(get_attack_lines)
DOMAIN="domain1.ac.id"
PASSWORDS=("admin123" "password" "123456" "letmein" "welcome" "passw0rd" "admin" "root" "test" "1234")

# Failed login attempts
for ((i=0; i<COUNT-2; i++)); do
    pass="${PASSWORDS[$((RANDOM % ${#PASSWORDS[@]}))]}"
    inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "POST" "/wp-login.php" "200" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    inject_apache_error "$AGENTS_SHARED" "$DOMAIN" "warn" "$ATTACKER_IP" "Authentication failed for admin from ${ATTACKER_IP}"
done

# Successful login
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "POST" "/wp-login.php" "302" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
inject_apache_access "$AGENTS_SHARED" "$DOMAIN" "$ATTACKER_IP" "GET" "/wp-admin/" "200"
inject_apache_error "$AGENTS_SHARED" "$DOMAIN" "info" "$ATTACKER_IP" "Authentication successful for admin from ${ATTACKER_IP}"

log_orch "scenario=web-bruteforce lines=${COUNT} attacker=${ATTACKER_IP}"
