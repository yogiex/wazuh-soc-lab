#!/bin/bash
# Jalankan Wazuh agent dulu
/var/ossec/bin/wazuh-control start
# Jalankan Apache di foreground
apachectl -D FOREGROUND
