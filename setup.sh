#!/bin/bash
# setup-wazuh-lab.sh
# -------------------
# Script ini akan membuat semua folder & file yang diperlukan untuk
# lab Wazuh belajar log Sangfor, WAF, dan shared hosting.
# Pastikan dijalankan di folder project yang kosong.

set -e

echo "📁 Membuat struktur folder..."
mkdir -p config/wazuh_manager
mkdir -p config/wazuh_indexer_ssl_certs

# ============================================================
# docker-compose.yml (Wazuh Indexer + Manager + Dashboard + Shared Hosting)
# ============================================================
cat > docker-compose.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  wazuh-indexer:
    image: wazuh/wazuh-indexer:4.9.0
    hostname: wazuh-indexer
    container_name: wazuh-indexer
    environment:
      - "OPENSEARCH_JAVA_OPTS=-Xms1g -Xmx1g"
      - "bootstrap.memory_lock=true"
      - "DISABLE_INSTALL_DEMO_CONFIG=true"
      - "DISABLE_SECURITY_PLUGIN=false"
      - "OPENSEARCH_INITIAL_ADMIN_PASSWORD=MyStr0ngP@ssw0rd!"
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    volumes:
      - wazuh-indexer-data:/var/lib/wazuh-indexer
      - ./config/wazuh_indexer_ssl_certs:/usr/share/wazuh-indexer/config/certs:ro
    ports:
      - "9200:9200"
    networks:
      - wazuh-net

  wazuh-manager:
    image: wazuh/wazuh-manager:4.9.0
    hostname: wazuh-manager
    container_name: wazuh-manager
    depends_on:
      - wazuh-indexer
    environment:
      - "INDEXER_URL=https://wazuh-indexer:9200"
      - "INDEXER_USERNAME=admin"
      - "INDEXER_PASSWORD=MyStr0ngP@ssw0rd!"
      - "API_USERNAME=wazuh"
      - "API_PASSWORD=wazuh"
      - "FILEBEAT_SSL_VERIFICATION_MODE=full"
      - "SSL_CERTIFICATE_AUTHORITIES=/etc/ssl/root-ca.pem"
      - "SSL_CERTIFICATE=/etc/ssl/filebeat.pem"
      - "SSL_KEY=/etc/ssl/filebeat.key"
    volumes:
      - wazuh-manager-data:/var/ossec/data
      - wazuh-manager-logs:/var/ossec/logs
      - wazuh-manager-config:/wazuh-config-mount
      - ./config/wazuh_indexer_ssl_certs/root-ca.pem:/etc/ssl/root-ca.pem:ro
      - ./config/wazuh_indexer_ssl_certs/wazuh-manager.pem:/etc/ssl/filebeat.pem:ro
      - ./config/wazuh_indexer_ssl_certs/wazuh-manager-key.pem:/etc/ssl/filebeat.key:ro
      # Mount custom manager configuration
      - ./config/wazuh_manager/ossec.conf:/wazuh-config-mount/etc/ossec.conf:ro
      - ./config/wazuh_manager/local_rules.xml:/wazuh-config-mount/etc/rules/local_rules.xml:ro
      - ./config/wazuh_manager/local_decoder.xml:/wazuh-config-mount/etc/decoders/local_decoder.xml:ro
    ports:
      - "1514:1514/udp"          # syslog receiver
      - "1515:1515"              # agent registration
      - "55000:55000"            # Wazuh API
    networks:
      - wazuh-net

  wazuh-dashboard:
    image: wazuh/wazuh-dashboard:4.9.0
    hostname: wazuh-dashboard
    container_name: wazuh-dashboard
    depends_on:
      - wazuh-indexer
    environment:
      - "INDEXER_URL=https://wazuh-indexer:9200"
      - "INDEXER_USERNAME=admin"
      - "INDEXER_PASSWORD=MyStr0ngP@ssw0rd!"
      - "WAZUH_API_URL=https://wazuh-manager:55000"
      - "API_USERNAME=wazuh"
      - "API_PASSWORD=wazuh"
      - "DASHBOARD_USERNAME=kibanaserver"
      - "DASHBOARD_PASSWORD=kibanaserver"
      - "PATTERN=wazuh-alerts-*"
      - "CHECKS_PATTERN=true"
      - "CHECKS_TEMPLATE=true"
      - "CHECKS_API=true"
      - "CHECKS_SETUP=true"
      - "EXTENSIONS_PCI=true"
      - "EXTENSIONS_GDPR=true"
      - "EXTENSIONS_HIPAA=true"
      - "EXTENSIONS_NIST=true"
      - "EXTENSIONS_TSC=true"
      - "EXTENSIONS_AUDIT=true"
      - "EXTENSIONS_OSCAP=true"
      - "EXTENSIONS_CISCAT=true"
      - "EXTENSIONS_AWS=true"
      - "EXTENSIONS_GCP=true"
      - "EXTENSIONS_AZURE=true"
      - "EXTENSIONS_VIRUSTOTAL=true"
      - "EXTENSIONS_OSQUERY=true"
      - "EXTENSIONS_DOCKER=true"
      - "APP_LOGOUT_TIME=3600000"
      - "DISABLE_TELEMETRY=true"
      - "SERVER_BASEPATH=/"
      - "SERVER_PORT=5601"
      - "SERVER_SSL_ENABLED=true"
      - "SERVER_SSL_CERTIFICATE=/usr/share/wazuh-dashboard/certs/wazuh-dashboard.pem"
      - "SERVER_SSL_KEY=/usr/share/wazuh-dashboard/certs/wazuh-dashboard-key.pem"
    volumes:
      - ./config/wazuh_indexer_ssl_certs/wazuh-dashboard.pem:/usr/share/wazuh-dashboard/certs/wazuh-dashboard.pem:ro
      - ./config/wazuh_indexer_ssl_certs/wazuh-dashboard-key.pem:/usr/share/wazuh-dashboard/certs/wazuh-dashboard-key.pem:ro
      - ./config/wazuh_indexer_ssl_certs/root-ca.pem:/usr/share/wazuh-dashboard/certs/root-ca.pem:ro
    ports:
      - "443:5601"
    networks:
      - wazuh-net

  # --- Container simulasi shared hosting ---
  shared-hosting:
    build:
      context: .
      dockerfile: Dockerfile.shared
      args:
        - WAZUH_MANAGER=wazuh-manager
    container_name: shared-hosting
    hostname: shared-hosting
    networks:
      - wazuh-net
    ports:
      - "8080:80"   # akses website simulasi di http://localhost:8080
    depends_on:
      - wazuh-manager

volumes:
  wazuh-indexer-data:
  wazuh-manager-data:
  wazuh-manager-logs:
  wazuh-manager-config:

networks:
  wazuh-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.23.0.0/24
COMPOSE_EOF

# ============================================================
# ossec.conf untuk Wazuh Manager (syslog receiver + rule includes)
# ============================================================
cat > config/wazuh_manager/ossec.conf << 'OSSE_EOF'
<ossec_config>
  <global>
    <jsonout_output>yes</jsonout_output>
    <alerts_log>yes</alerts_log>
    <logall>no</logall>
    <logall_json>no</logall_json>
    <email_notification>no</email_notification>
    <smtp_server>localhost</smtp_server>
    <email_from>wazuh@example.com</email_from>
    <email_to>admin@example.com</email_to>
    <email_maxperhour>12</email_maxperhour>
    <email_log_source>alerts.log</email_log_source>
    <agents_disconnection_time>10m</agents_disconnection_time>
    <agents_disconnection_alert_time>0</agents_disconnection_alert_time>
    <update_check>no</update_check>
  </global>

  <rules>
    <include>rules_config.xml</include>
    <include>rules/*.xml</include>
    <include>etc/rules/local_rules.xml</include>
  </rules>

  <decoders>
    <include>decoders/*.xml</include>
    <include>etc/decoders/local_decoder.xml</include>
  </decoders>

  <!-- Syslog receiver untuk Sangfor & WAF -->
  <remote>
    <connection>syslog</connection>
    <port>1514</port>
    <protocol>udp</protocol>
    <allowed-ips>0.0.0.0/0</allowed-ips>
    <local_ip>0.0.0.0</local_ip>
  </remote>

  <!-- Agent auth -->
  <auth>
    <disabled>no</disabled>
    <port>1515</port>
    <use_source_ip>no</use_source_ip>
    <force_insert>yes</force_insert>
    <force_time>no</force_time>
    <purge>no</purge>
    <use_password>no</use_password>
    <ciphers>HIGH:!ADH:!EXP:!MD5:!RC4:!3DES:!CAMELLIA:@STRENGTH</ciphers>
    <ssl_agent_ca>/etc/ssl/root-ca.pem</ssl_agent_ca>
    <ssl_verify_host>no</ssl_verify_host>
    <ssl_manager_cert>/etc/ssl/filebeat.pem</ssl_manager_cert>
    <ssl_manager_key>/etc/ssl/filebeat.key</ssl_manager_key>
    <ssl_auto_negotiate>no</ssl_auto_negotiate>
  </auth>
</ossec_config>
OSSE_EOF

# Decoder & rule kosong (akan diisi sesuai kebutuhan)
cat > config/wazuh_manager/local_decoder.xml << 'DEC_EOF'
<decoders>
</decoders>
DEC_EOF

cat > config/wazuh_manager/local_rules.xml << 'RULES_EOF'
<group name="local,syslog,">
</group>
RULES_EOF

# ============================================================
# Dockerfile untuk container shared hosting
# ============================================================
cat > Dockerfile.shared << 'DOCKER_EOF'
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install Apache, Wazuh agent, dan tools
RUN apt-get update && apt-get install -y \
    apache2 \
    curl \
    gnupg \
    lsb-release \
    && rm -rf /var/lib/apt/lists/*

# Aktifkan modul Apache yang umum dipakai
RUN a2enmod rewrite ssl headers

# Buat struktur shared hosting
RUN mkdir -p /home/domain1.ac.id/public_html /home/domain1.ac.id/logs \
    && mkdir -p /home/domain2.ac.id/public_html /home/domain2.ac.id/logs \
    && echo "<h1>Domain 1</h1>" > /home/domain1.ac.id/public_html/index.html \
    && echo "<h1>Domain 2</h1>" > /home/domain2.ac.id/public_html/index.html

# Konfigurasi virtual host
COPY shared-hosting.conf /etc/apache2/sites-available/shared-hosting.conf
RUN a2dissite 000-default.conf && a2ensite shared-hosting.conf

# Pasang Wazuh agent
ARG WAZUH_MANAGER="wazuh-manager"
RUN curl -s https://packages.wazuh.com/key/GPG-KEY-WAZUH | apt-key add - \
    && echo "deb https://packages.wazuh.com/4.x/apt/ stable main" | tee /etc/apt/sources.list.d/wazuh.list \
    && apt-get update && apt-get install -y wazuh-agent \
    && sed -i "s/^MANAGER_IP=.*/MANAGER_IP=${WAZUH_MANAGER}/" /etc/ossec-init.conf \
    && sed -i "s/^address:.*/address: ${WAZUH_MANAGER}/" /var/ossec/etc/ossec.conf

# Konfigurasi agent untuk membaca log Apache
COPY wazuh-agent-ossec.conf /var/ossec/etc/ossec.conf

# Expose port 80
EXPOSE 80

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
DOCKER_EOF

# ============================================================
# Konfigurasi Apache virtual host
# ============================================================
cat > shared-hosting.conf << 'APACHE_EOF'
<VirtualHost *:80>
    ServerName domain1.ac.id
    DocumentRoot /home/domain1.ac.id/public_html
    ErrorLog /home/domain1.ac.id/logs/error.log
    CustomLog /home/domain1.ac.id/logs/access.log combined
</VirtualHost>

<VirtualHost *:80>
    ServerName domain2.ac.id
    DocumentRoot /home/domain2.ac.id/public_html
    ErrorLog /home/domain2.ac.id/logs/error.log
    CustomLog /home/domain2.ac.id/logs/access.log combined
</VirtualHost>
APACHE_EOF

# ============================================================
# Konfigurasi Wazuh agent (monitor file log Apache)
# ============================================================
cat > wazuh-agent-ossec.conf << 'AGENT_EOF'
<ossec_config>
  <client>
    <server>
      <address>wazuh-manager</address>
      <port>1514</port>
      <protocol>tcp</protocol>
    </server>
    <config-profile>shared-hosting</config-profile>
    <crypto_method>aes</crypto_method>
  </client>

  <localfile>
    <location>/home/domain1.ac.id/logs/access.log</location>
    <log_format>apache</log_format>
    <frequency>10</frequency>
  </localfile>

  <localfile>
    <location>/home/domain1.ac.id/logs/error.log</location>
    <log_format>apache</log_format>
    <frequency>10</frequency>
  </localfile>

  <localfile>
    <location>/home/domain2.ac.id/logs/access.log</location>
    <log_format>apache</log_format>
    <frequency>10</frequency>
  </localfile>

  <localfile>
    <location>/home/domain2.ac.id/logs/error.log</location>
    <log_format>apache</log_format>
    <frequency>10</frequency>
  </localfile>

  <localfile>
    <location>/var/ossec/logs/active-responses.log</location>
    <log_format>syslog</log_format>
  </localfile>
</ossec_config>
AGENT_EOF

# ============================================================
# Entrypoint container shared hosting
# ============================================================
cat > entrypoint.sh << 'ENTRY_EOF'
#!/bin/bash
# Jalankan Wazuh agent dulu
/var/ossec/bin/wazuh-control start
# Jalankan Apache di foreground
apachectl -D FOREGROUND
ENTRY_EOF
chmod +x entrypoint.sh

echo "✅ Semua file berhasil dibuat!"
echo ""
echo "========================================="
echo "🚀 Langkah selanjutnya:"
echo "========================================="
echo "1. Generate sertifikat SSL untuk Wazuh Indexer:"
echo "   cd /tmp"
echo "   git clone https://github.com/wazuh/wazuh-docker.git -b v4.9.0"
echo "   cd wazuh-docker/single-node"
echo "   docker compose -f generate-indexer-certs.yml run --rm generator"
echo ""
echo "   Setelah selesai, salin sertifikat ke project ini:"
echo "   cp -r config/wazuh_indexer_ssl_certs/* \\"
echo "       ~/Documents/code/sec/wazuh-belajar/config/wazuh_indexer_ssl_certs/"
echo ""
echo "2. Build dan jalankan semua container:"
echo "   cd ~/Documents/code/sec/wazuh-belajar"
echo "   docker compose up -d --build"
echo ""
echo "3. Akses dashboard Wazuh di https://localhost"
echo "   (username: kibanaserver, password: kibanaserver)"
echo ""
echo "4. Shared hosting bisa diakses di http://localhost:8080"
echo "   (gunakan header Host: domain1.ac.id atau domain2.ac.id jika perlu)"
echo "========================================="