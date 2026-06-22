#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/orchestrator.conf"
source "$SCRIPT_DIR/inject-common.sh"

COUNT=$(get_attack_lines)

declare -a EVENTS
EVENTS=(
    "src=172.16.0.10 dst=203.0.113.50 rule=SQLi method=GET uri=/login?id=1%27%20OR%20%271%27%3D%271 waf_status=403"
    "src=172.16.0.11 dst=203.0.113.51 rule=XSS method=GET uri=/search?q=%3Cscript%3Ealert(1)%3C/script%3E waf_status=403"
    "src=172.16.0.12 dst=203.0.113.52 rule=LFI method=GET uri=/page?file=../../../etc/passwd waf_status=403"
    "src=172.16.0.13 dst=203.0.113.53 rule=RCE method=POST uri=/admin/ping waf_status=403"
    "src=172.16.0.14 dst=203.0.113.54 rule=SQLi method=POST uri=/login waf_status=403"
    "src=172.16.0.15 dst=203.0.113.55 rule=PathTraversal method=GET uri=/download?file=..%2f..%2f..%2fetc%2fpasswd waf_status=403"
    "src=172.16.0.16 dst=203.0.113.56 rule=Scanner method=GET uri=/.env waf_status=403"
    "src=172.16.0.17 dst=203.0.113.57 rule=WebShell method=POST uri=/upload waf_status=403"
    "src=172.16.0.18 dst=203.0.113.58 rule=SQLi method=GET uri=/products?id=1+UNION+SELECT+1,2,3-- waf_status=403"
    "src=172.16.0.19 dst=203.0.113.59 rule=XSS method=POST uri=/comment waf_status=403"
)

for ((i=0; i<COUNT; i++)); do
    event="${EVENTS[$((RANDOM % ${#EVENTS[@]}))]}"
    inject_syslog "131" "WAF-01" "$event"
done

log_orch "scenario=waf-logs lines=${COUNT}"
