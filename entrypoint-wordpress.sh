#!/bin/bash

# Jalankan MariaDB
service mariadb start

# Tunggu hingga siap
until mysqladmin ping -u root --silent; do
    sleep 1
done

# Buat database dan user untuk tiap domain
for i in 1 2 3 4 5; do
    DB_NAME="wordpress_domain${i}"
    DB_USER="wp_user_${i}"
    DB_PASS=$(openssl rand -base64 12)
    
    mysql -u root -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
    mysql -u root -e "CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    mysql -u root -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
    mysql -u root -e "FLUSH PRIVILEGES;"
    
    # Update wp-config.php
    sed -i "s|database_name_here|${DB_NAME}|" /home/domain${i}.ac.id/public_html/wp-config.php
    sed -i "s|username_here|${DB_USER}|" /home/domain${i}.ac.id/public_html/wp-config.php
    sed -i "s|password_here|${DB_PASS}|" /home/domain${i}.ac.id/public_html/wp-config.php
done

# Daftarkan Wazuh agent jika belum terdaftar, lalu jalankan
/register-agent.sh
/var/ossec/bin/wazuh-control start

# Jalankan Apache di foreground
apachectl -D FOREGROUND