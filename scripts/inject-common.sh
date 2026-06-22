#!/bin/bash

get_attack_lines() {
    case "$INTENSITY" in
        low)    echo "$ATTACK_LINES_LOW" ;;
        medium) echo "$ATTACK_LINES_MEDIUM" ;;
        high)   echo "$ATTACK_LINES_HIGH" ;;
        *)      echo "$ATTACK_LINES_MEDIUM" ;;
    esac
}

get_normal_lines() {
    case "$INTENSITY" in
        low)    echo "$NORMAL_LINES_LOW" ;;
        medium) echo "$NORMAL_LINES_MEDIUM" ;;
        high)   echo "$NORMAL_LINES_HIGH" ;;
        *)      echo "$NORMAL_LINES_MEDIUM" ;;
    esac
}

apache_ts() {
    date '+%d/%b/%Y:%H:%M:%S %z'
}

auth_ts() {
    date '+%b %d %H:%M:%S'
}

syslog_ts() {
    date '+%Y-%m-%dT%H:%M:%SZ'
}

random_ip() {
    echo "10.0.0.$((RANDOM % 250 + 10))"
}

random_ua() {
    local agents=(
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
        "curl/7.88.1"
        "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"
        "python-requests/2.31.0"
    )
    echo "${agents[$RANDOM % ${#agents[@]}]}"
}

inject_apache_access() {
    local agent="$1" domain="$2" ip="$3" method="$4" uri="$5" code="$6"
    local ua="${7:-$(random_ua)}"
    local size="$((RANDOM % 5000 + 200))"
    local ts=$(apache_ts)
    echo "${ip} - - [${ts}] \"${method} ${uri} HTTP/1.1\" ${code} ${size} \"-\" \"${ua}\"" \
        | docker exec -i "$agent" tee -a "/home/${domain}/logs/access.log" > /dev/null 2>&1
}

inject_apache_error() {
    local agent="$1" domain="$2" level="$3" client="$4" message="$5"
    local ts=$(apache_ts)
    echo "[${ts}] [${level}] [client ${client}] ${message}" \
        | docker exec -i "$agent" tee -a "/home/${domain}/logs/error.log" > /dev/null 2>&1
}

inject_auth() {
    local agent="$1" entry="$2"
    local ts=$(auth_ts)
    local hn=$(docker exec "$agent" hostname 2>/dev/null || echo "$agent")
    echo "${ts} ${hn} ${entry}" \
        | docker exec -i "$agent" tee -a /var/log/auth.log > /dev/null 2>&1
}

inject_syslog() {
    local priority="$1" app="$2" message="$3"
    local ts=$(syslog_ts)
    echo "<${priority}>${ts} ${app} ${message}" \
        | nc -u -w0 "$SYSLOG_TARGET" "$SYSLOG_PORT" 2>/dev/null
}

inject_file_write() {
    local agent="$1" filepath="$2"
    shift 2
    echo "$*" | docker exec -i "$agent" tee "$filepath" > /dev/null 2>&1
}

inject_file_append() {
    local agent="$1" filepath="$2"
    shift 2
    echo "$*" | docker exec -i "$agent" tee -a "$filepath" > /dev/null 2>&1
}

inject_file_rm() {
    local agent="$1" filepath="$2"
    docker exec "$agent" rm -f "$filepath" 2>/dev/null
}

log_orch() {
    echo "[orchestrator] $(date '+%Y-%m-%d %H:%M:%S') | $*"
}
