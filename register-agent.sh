#!/bin/bash

MANAGER_IP="${WAZUH_MANAGER:-wazuh-manager}"
API_USER="${WAZUH_API_USER:-wazuh}"
API_PASS="${WAZUH_API_PASS:-MyS3cur3P@ss!}"

if [ -f /var/ossec/etc/client.keys ] && [ -s /var/ossec/etc/client.keys ]; then
    echo "register-agent: Agent already registered, skipping..."
    exit 0
fi

AGENT_NAME="$(hostname)"

echo "register-agent: Registering agent '${AGENT_NAME}' with ${MANAGER_IP}..."

TOKEN=$(curl -s -u "${API_USER}:${API_PASS}" -k "https://${MANAGER_IP}:55000/security/user/authenticate" \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['token'])" 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo "register-agent: FAILED to authenticate with Wazuh API"
    exit 1
fi

RESP=$(curl -s -k -X POST "https://${MANAGER_IP}:55000/agents" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"${AGENT_NAME}\",\"force\":true}")

AGENT_KEY=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['key'])" 2>/dev/null)

if [ -z "$AGENT_KEY" ]; then
    echo "register-agent: FAILED to register: $RESP"
    exit 1
fi

echo "$AGENT_KEY" | base64 -d > /var/ossec/etc/client.keys
echo "register-agent: Registered successfully (ID $(awk '{print $1}' /var/ossec/etc/client.keys))"
