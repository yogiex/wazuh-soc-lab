#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/orchestrator.conf"
source "${SCRIPT_DIR}/inject-common.sh"

log_orch "Orchestrator started | mode=${CYCLE_MODE} intensity=${INTENSITY} interval=${ATTACK_INTERVAL}s"

SCENARIO_LIST=($ENABLED_SCENARIOS)
SCENARIO_INDEX=0

inject_scenario() {
    local name="$1"
    local script="${SCRIPT_DIR}/scenarios/${name}.sh"
    if [[ -f "$script" ]]; then
        log_orch "scenario=START name=${name}"
        bash "$script" 2>/dev/null
        log_orch "scenario=DONE  name=${name}"
    else
        log_orch "scenario=SKIP  name=${name} (not found)"
    fi
}

inject_normal_traffic() {
    local agent domains
    for agent in "$AGENTS_SHARED" "$AGENTS_MULTI"; do
        case "$agent" in
            shared-hosting) domains=("domain1.ac.id" "domain2.ac.id" "domain3.ac.id") ;;
            multi-site)     domains=("labs.ac.id") ;;
            *) continue ;;
        esac

        local count=$(get_normal_lines)
        for dom in "${domains[@]}"; do
            for ((i=0; i<count; i++)); do
                local ip=$(random_ip)
                local uri
                case $((RANDOM % 8)) in
                    0) uri="/" ;;
                    1) uri="/wp-content/themes/style.css" ;;
                    2) uri="/wp-content/themes/script.js" ;;
                    3) uri="/wp-content/uploads/image${RANDOM}.jpg" ;;
                    4) uri="/wp-includes/js/jquery.js" ;;
                    5) uri="/index.html" ;;
                    6) uri="/robots.txt" ;;
                    7) uri="/favicon.ico" ;;
                esac
                inject_apache_access "$agent" "$dom" "$ip" "GET" "$uri" "200"
            done
        done
    done
    log_orch "type=NORMAL lines=$(get_normal_lines) targets=shared-hosting,multi-site"
}

cleanup() {
    log_orch "Orchestrator stopped"
    exit 0
}
trap cleanup SIGTERM SIGINT

while true; do
    if [[ "$NORMAL_INJECT" == "yes" ]]; then
        inject_normal_traffic
    fi
    sleep "$BASELINE_INTERVAL"

    scenario=
    case "$CYCLE_MODE" in
        sequential)
            scenario="${SCENARIO_LIST[$SCENARIO_INDEX]}"
            SCENARIO_INDEX=$(( (SCENARIO_INDEX + 1) % ${#SCENARIO_LIST[@]} ))
            ;;
        random)
            scenario="${SCENARIO_LIST[$RANDOM % ${#SCENARIO_LIST[@]}]}"
            ;;
        all-once)
            for s in "${SCENARIO_LIST[@]}"; do
                inject_scenario "$s"
            done
            log_orch "All scenarios done. Exiting."
            exit 0
            ;;
        *)
            log_orch "ERROR: unknown CYCLE_MODE=$CYCLE_MODE"
            exit 1
            ;;
    esac

    inject_scenario "$scenario"
    sleep "$ATTACK_INTERVAL"
done
