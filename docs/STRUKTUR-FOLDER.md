wazuh-belajar/
├── config/
│ ├── wazuh_indexer_ssl_certs/ (di‑generate)
│ └── wazuh_manager/
│ ├── local_decoder.xml
│ ├── local_rules.xml
│ └── ossec.conf
├── docker-compose.yml
├── Dockerfile.shared # Container shared hosting
├── Dockerfile.multi-site # Container multi‑site
├── shared-hosting.conf # VirtualHost untuk shared hosting
├── wazuh-agent-shared.conf # Konfigurasi agent untuk shared
├── multi-site.conf # VirtualHost untuk multi‑site
├── wazuh-agent-multisite.conf # Konfigurasi agent untuk multi‑site
├── entrypoint.sh # Startup script (dipakai kedua container)
├── setup.sh (opsional)
└── README.md
