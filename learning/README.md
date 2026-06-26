# Wazuh Query Learning Lab

Folder ini berisi 10 modul untuk belajar melakukan query di Wazuh Dashboard
mulai dari basic discovery hingga advanced visualizations.

## Prasyarat

- Wazuh Dashboard akses: `https://localhost:5601`
- Login: `kibanaserver` / `kibanaserver` (atau `admin` / `MyStr0ngP@ssw0rd!`)
- Index pattern: `wazuh-alerts-*`
- Stack sudah running: `docker-compose ps`

## Cara Pakai

1. Buka **Wazuh Dashboard** → **Discover** (atau Dev Tools untuk modul 4)
2. Copy-paste contoh query dari tiap modul
3. Sesuaikan time range (default: Last 24h)
4. Observasi hasilnya, lalu coba modifikasi

## Daftar Modul

| # | Modul | Topik |
|---|-------|-------|
| 01 | `discover-basics` | Navigasi Discover, Field Sidebar, Add Filter, Edit as Query DSL |
| 02 | `kql-syntax` | KQL: field:value, and/or/not, parenthes, wildcard |
| 03 | `lucene-syntax` | Lucene: regex, fuzzy, proximity, range, boost |
| 04 | `dev-tools-opensearch-dsl` | Dev Tools: _search, match/term/bool, _source filtering |
| 05 | `wazuh-api-wql` | Wazuh Query Language via REST API |
| 06 | `filtering-time-ranges` | Date math, custom range, nested field filter |
| 07 | `alert-analysis` | rule, agent, groups, data.attack_type, WAF+Domain timeline |
| 08 | `fim-integrity-monitoring` | syscheck.path, event, hash queries |
| 09 | `aggregations-statistics` | Terms agg, cardinality, date histogram, top N |
| 10 | `visualizations-dashboards` | Saved search → Visualize → Dashboard |
| 11 | `parasite-seo-detection` | Deteksi SEO Cloaking / Parasite SEO |
| 12 | `wordpress-sca` | WordPress Security Assessment dengan SCA (11+ checks) |

## Referensi

- [Wazuh Query Filtering](https://documentation.wazuh.com/current/user-manual/wazuh-dashboard/wazuh-query-filters.html)
- [OpenSearch Query DSL](https://opensearch.org/docs/latest/query-dsl/)
- [OpenSearch Dashboards Discover](https://opensearch.org/docs/latest/dashboards/discover/)
