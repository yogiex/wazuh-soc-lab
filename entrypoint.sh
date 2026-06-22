#!/bin/bash
/register-agent.sh
/var/ossec/bin/wazuh-control start
apachectl -D FOREGROUND