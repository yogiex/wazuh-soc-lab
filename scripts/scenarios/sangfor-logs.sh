#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/orchestrator.conf"
source "$SCRIPT_DIR/inject-common.sh"

COUNT=$(get_attack_lines)

declare -a EVENTS
EVENTS=(
    "devid=NGAF-01 src=10.10.0.50 dst=203.0.113.1 actions=blocked attack_type=\"SQL Injection\" policy=\"Block High Risk\" type=web-attack severity=high"
    "devid=NGAF-01 src=10.10.0.51 dst=203.0.113.2 actions=allowed attack_type=\"Web Access\" policy=\"Permit Low Risk\" type=web-access severity=low"
    "devid=NGAF-02 src=10.20.0.100 dst=198.51.100.10 actions=blocked attack_type=\"Botnet\" policy=\"Block Malicious IP\" type=botnet severity=critical"
    "devid=NGAF-01 src=10.10.0.52 dst=203.0.113.3 actions=blocked attack_type=\"SQL Injection\" policy=\"Block SQL Injection\" type=web-attack severity=high"
    "devid=NGAF-02 src=10.20.0.101 dst=198.51.100.11 actions=alerted attack_type=\"Port Scan\" policy=\"Alert Suspicious\" type=port-scan severity=medium"
    "devid=NGAF-01 src=10.10.0.53 dst=203.0.113.4 actions=blocked attack_type=\"XSS Attack\" policy=\"Block XSS Attack\" type=web-attack severity=high"
    "devid=NGAF-02 src=10.20.0.102 dst=198.51.100.12 actions=allowed attack_type=\"Business Traffic\" policy=\"Permit Business\" type=web-access severity=low"
    "devid=NGAF-01 src=10.10.0.54 dst=203.0.113.5 actions=blocked attack_type=\"DDoS\" policy=\"Block DDoS\" type=ddos severity=critical"
)

for ((i=0; i<COUNT; i++)); do
    event="${EVENTS[$((RANDOM % ${#EVENTS[@]}))]}"
    if (( RANDOM % 4 == 0 )); then
        pr="134"
    elif (( RANDOM % 3 == 0 )); then
        pr="142"
    else
        pr="130"
    fi
    inject_syslog "$pr" "SangforNGAF" "$event"
done

log_orch "scenario=sangfor-logs lines=${COUNT}"
