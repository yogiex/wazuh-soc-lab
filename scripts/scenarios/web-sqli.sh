#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/orchestrator.conf"
source "$SCRIPT_DIR/inject-common.sh"

ATTACKER_IP="10.0.0.66"
COUNT=$(get_attack_lines)
DOMAINS=("domain1.ac.id" "domain2.ac.id")

SQLI_PAYLOADS=(
    "/product?id=1'+OR+'1'%3D'1"
    "/product?id=1'+UNION+SELECT+1,2,3--"
    "/page?id=1'+AND+1%3D1--"
    "/page?id=1'+AND+1%3D2--"
    "/search?q=test'+OR+'1'%3D'1'--"
    "/search?q='+UNION+SELECT+@@version--"
    "/wp-admin/admin-ajax.php?action=test&id=-1'+UNION+SELECT+1,user_pass,3+FROM+wp_users--"
    "/product?id=1'+WAITFOR+DELAY+'0:0:5'--"
    "/product?id=1'+BENCHMARK(5000000,MD5(1))--"
    "/page?id=1'+ORDER+BY+10--"
    "/page?id=1'+GROUP+BY+1,2,3+HAVING+1%3D1--"
)

ERROR_PAYLOADS=(
    "/product?id=1'"
    "/product?id=1\""
    "/page?id=1'%5C"
)

for ((i=0; i<COUNT; i++)); do
    dom="${DOMAINS[$((RANDOM % ${#DOMAINS[@]}))]}"
    if (( RANDOM % 5 == 0 )); then
        payload="${ERROR_PAYLOADS[$((RANDOM % ${#ERROR_PAYLOADS[@]}))]}"
        code="500"
    else
        payload="${SQLI_PAYLOADS[$((RANDOM % ${#SQLI_PAYLOADS[@]}))]}"
        code="200"
    fi
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "$payload" "$code" "sqlmap/1.8 (http://sqlmap.org)"
done

# Multi-site
MS_SQLI=("/prosman/?id=1'+OR+'1'%3D'1" "/keamanan/?id=1'+UNION+SELECT+1,2,3--" "/jaringan/?page=1'+AND+1%3D1--" "/web/?id=1'+ORDER+BY+10--")
for ((i=0; i<COUNT/4; i++)); do
    uri="${MS_SQLI[$((RANDOM % ${#MS_SQLI[@]}))]}"
    inject_apache_access "$AGENTS_MULTI" "labs.ac.id" "$ATTACKER_IP" "GET" "$uri" "200" "sqlmap/1.8 (http://sqlmap.org)"
done

# Error log entries
for ((i=0; i<5; i++)); do
    dom="${DOMAINS[$((RANDOM % ${#DOMAINS[@]}))]}"
    inject_apache_error "$AGENTS_SHARED" "$dom" "error" "$ATTACKER_IP" "WordPress database error You have an error in your SQL syntax for query SELECT * FROM wp_posts WHERE ID ="
done

log_orch "scenario=web-sqli lines=$((COUNT + COUNT/4)) attacker=${ATTACKER_IP}"
