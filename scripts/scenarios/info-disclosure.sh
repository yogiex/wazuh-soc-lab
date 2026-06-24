#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$SCRIPT_DIR/orchestrator.conf"
source "$SCRIPT_DIR/inject-common.sh"

ATTACKER_IP="10.0.0.210"
COUNT=$(get_attack_lines)
SHARED_DOMAINS=("domain1.ac.id" "domain2.ac.id" "domain3.ac.id" "domain4.ac.id" "domain5.ac.id")
CURL_UA="curl/7.88.1"
PYTHON_UA="python-requests/2.31.0"

# ---- Backup file disclosure ----
BACKUP_PATHS=(
    "wp-config.php~"
    "wp-config.php.bak"
    "wp-config.php.old"
    "wp-config.php.swp"
    "wp-config.php.save"
    "index.php~"
    "index.php.bak"
    ".htaccess.bak"
    ".htaccess.old"
)
for ((i=0; i<COUNT/3; i++)); do
    dom="${SHARED_DOMAINS[$((RANDOM % ${#SHARED_DOMAINS[@]}))]}"
    uri="${BACKUP_PATHS[$((RANDOM % ${#BACKUP_PATHS[@]}))]}"
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "/${uri}" "200" "$CURL_UA"
done

# ---- Config / source code disclosure ----
CONFIG_PATHS=(
    "/.env"
    "/.git/config"
    "/.git/HEAD"
    "/.svn/entries"
    "/.DS_Store"
    "/composer.json"
    "/composer.lock"
    "/package.json"
    "/package-lock.json"
    "/wp-config-sample.php"
    "/wp-content/debug.log"
    "/error_log"
    "/error.log"
)
for ((i=0; i<COUNT/3; i++)); do
    dom="${SHARED_DOMAINS[$((RANDOM % ${#SHARED_DOMAINS[@]}))]}"
    uri="${CONFIG_PATHS[$((RANDOM % ${#CONFIG_PATHS[@]}))]}"
    code=$((RANDOM % 5 == 0 ? 200 : 404))
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "$uri" "$code" "$PYTHON_UA"
done

# ---- Database dump files ----
DB_PATHS=(
    "/backup.sql"
    "/db.sql"
    "/dump.sql"
    "/database.sql"
    "/wp-content/backup/database.sql"
    "/wp-content/backup/db.sql"
    "/wp-content/uploads/backup.sql"
    "/backup.sql.gz"
    "/db_backup.sql"
    "/sql/backup.sql"
)
for ((i=0; i<COUNT/4; i++)); do
    dom="${SHARED_DOMAINS[$((RANDOM % ${#SHARED_DOMAINS[@]}))]}"
    uri="${DB_PATHS[$((RANDOM % ${#DB_PATHS[@]}))]}"
    code=$((RANDOM % 6 == 0 ? 200 : 404))
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "$uri" "$code" "$CURL_UA"
done

# ---- PHP info / test files ----
PHPINFO_PATHS=(
    "/phpinfo.php"
    "/info.php"
    "/i.php"
    "/test.php"
    "/p.php"
    "/php_info.php"
    "/info.php3"
)
for ((i=0; i<COUNT/5; i++)); do
    dom="${SHARED_DOMAINS[$((RANDOM % ${#SHARED_DOMAINS[@]}))]}"
    uri="${PHPINFO_PATHS[$((RANDOM % ${#PHPINFO_PATHS[@]}))]}"
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "$uri" "200" "$CURL_UA"
done

# ---- Directory listing probes ----
DIR_PATHS=(
    "/wp-content/uploads/"
    "/wp-content/plugins/"
    "/wp-content/themes/"
    "/wp-includes/"
    "/wp-admin/css/"
    "/wp-content/"
    "/uploads/"
    "/backup/"
)
for ((i=0; i<COUNT/5; i++)); do
    dom="${SHARED_DOMAINS[$((RANDOM % ${#SHARED_DOMAINS[@]}))]}"
    uri="${DIR_PATHS[$((RANDOM % ${#DIR_PATHS[@]}))]}"
    code=$((RANDOM % 3 == 0 ? 403 : (RANDOM % 2 == 0 ? 301 : 200)))
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "$uri" "$code" "$PYTHON_UA"
done

# ---- Error-based disclosure (malformed requests) ----
for ((i=0; i<COUNT/6; i++)); do
    dom="${SHARED_DOMAINS[$((RANDOM % ${#SHARED_DOMAINS[@]}))]}"
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "GET" "/index.php?option=%00" "500" "$PYTHON_UA"
    inject_apache_error "$AGENTS_SHARED" "$dom" "error" "$ATTACKER_IP" \
        "PHP Fatal error:  Uncaught TypeError: Cannot access empty property in /home/${dom}/public_html/index.php on line 23"
    inject_apache_access "$AGENTS_SHARED" "$dom" "$ATTACKER_IP" "POST" "/wp-admin/admin-ajax.php" "500" "$PYTHON_UA"
    inject_apache_error "$AGENTS_SHARED" "$dom" "error" "$ATTACKER_IP" \
        "PHP Warning:  mysqli_connect(): (HY000/1045): Access denied for user 'root'@'localhost' (using password: NO) in /home/${dom}/public_html/wp-includes/wp-db.php on line 1634"
done

# ---- Multi-site info disclosure ----
MS_PATHS=(
    "/.git/config"
    "/.env"
    "/backup.sql"
    "/phpinfo.php"
    "/wp-config.php~"
    "/composer.json"
    "/debug.log"
)
for ((i=0; i<COUNT/4; i++)); do
    uri="${MS_PATHS[$((RANDOM % ${#MS_PATHS[@]}))]}"
    code=$((RANDOM % 5 == 0 ? 200 : 404))
    inject_apache_access "$AGENTS_MULTI" "labs.ac.id" "$ATTACKER_IP" "GET" "$uri" "$code" "$PYTHON_UA"
done

log_orch "scenario=info-disclosure lines=$((COUNT + COUNT/4)) attacker=${ATTACKER_IP}"
