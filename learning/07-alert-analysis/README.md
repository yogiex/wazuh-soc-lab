# 07 — Alert Analysis

Menganalisis alert Wazuh: rule, agent, groups, data.attack_type,
query WAF + domain timeline.

## 1. Struktur Alert Wazuh

Setiap alert di index `wazuh-alerts-*` memiliki struktur:

```
_source
├── rule
│   ├── id          → ID rule (100002, 100020, ...)
│   ├── level       → Severity (1-15)
│   ├── description → Deskripsi alert
│   ├── groups      → Array grup (attack, fim, recon, ...)
│   └── mitre       → MITRE ATT&CK mapping (id, tactic, technique)
├── data
│   ├── vhost       → Domain (hanya dari agent Apache)
│   ├── srcip       → IP sumber
│   ├── dstip       → IP tujuan
│   ├── attack_type → Tipe serangan (MITRE)
│   ├── rule        → Rule WAF (SQLi, XSS, LFI, RCE)
│   └── status      → HTTP status code
├── agent
│   ├── id          → 001, 002
│   ├── name        → shared-hosting, multi-site
│   └── version     → Wazuh v4.14.5
├── manager
│   └── name        → wazuh-manager
├── location        → Sumber log
└── @timestamp      → Waktu kejadian
```

## 2. Query Alert by Rule

**KQL:**
```
rule.id : 100020
rule.id : 100002 OR rule.id : 100010
rule.level >= 10
rule.level : 12
```

**Dev Tools:**
```
GET wazuh-alerts-*/_search
{
  "query": {"term": {"rule.id": "100020"}}
}
```

## 3. Query by Rule Groups

**KQL:**
```
rule.groups : "attack"
rule.groups : "fim"
rule.groups : "recon"
```

**Kombinasi:**
```
rule.groups : "attack" AND rule.level >= 10
```

## 4. Query by Agent

**KQL:**
```
agent.name : "shared-hosting"
agent.name : "multi-site"
agent.id : "001"
```

**Dev Tools:**
```
GET wazuh-alerts-*/_search
{
  "query": {"term": {"agent.name": "shared-hosting"}},
  "_source": ["rule.id", "rule.level", "data.vhost", "data.srcip"],
  "size": 20
}
```

## 5. Query data.attack_type (MITRE ATT&CK)

Field `data.attack_type` diisi jika rule memiliki mapping MITRE ATT&CK.

> **Catatan:** Rules custom 100002-100024 di lab ini belum punya tag `<mitre>`.
> Field ini akan muncul jika Anda menambahkan mapping MITRE ke `local_rules.xml`.

### Cari alert yang punya attack_type:
```
exists:data.attack_type
```

`data.attack_type : (*)` (KQL) atau `_exists_:data.attack_type` (Lucene)

### Cari berdasarkan tipe serangan tertentu:
```
data.attack_type : "WebShell"
data.attack_type : "SQL Injection"
data.attack_type : "Credential Access"
data.attack_type : "Persistence"
data.attack_type : "Execution"
data.attack_type : "Discovery"
```

### Kombinasi dengan domain:
```
data.attack_type : "WebShell" AND data.vhost : "domain1.ac.id"
```

### Dev Tools — Aggregation untuk lihat semua unique attack_type:
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "aggs": {
    "attack_types": {
      "terms": {"field": "data.attack_type", "size": 50}
    }
  }
}
```

## 6. Query WAF + Domain Timeline

WAF log dikirim via syslog UDP ke manager, bukan via agent.
WAF log memiliki field `data.rule` (SQLi, XSS, LFI, RCE, Scanner, dll).
WAF log **tidak memiliki** `data.vhost` (domain).

**Cari alert WAF:**
```
data.rule : (*)
data.rule : "SQLi"
data.rule : "XSS" OR data.rule : "RCE"
```

### Timeline WAF alert per jam (Dev Tools):
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "query": {
    "exists": {"field": "data.rule"}
  },
  "aggs": {
    "timeline": {
      "date_histogram": {"field": "@timestamp", "interval": "hour"},
      "aggs": {
        "by_rule": {"terms": {"field": "data.rule", "size": 10}}
      }
    }
  }
}
```

### Top attacker IP dari WAF:
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "query": {
    "exists": {"field": "data.rule"}
  },
  "aggs": {
    "top_attackers": {
      "terms": {"field": "data.srcip", "size": 20}
    }
  }
}
```

## 7. Studi Kasus: Domain Attack Timeline

**Tujuan:** Tampilkan timeline serangan untuk `domain1.ac.id`
dalam 7 hari, dikelompokkan per tipe serangan.

**KQL di Discover:**
```
data.vhost : "domain1.ac.id" AND rule.groups : "attack"
```

**Dev Tools — Timeline aggregation:**
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "query": {
    "bool": {
      "must": [
        {"term": {"data.vhost": "domain1.ac.id"}},
        {"match": {"rule.groups": "attack"}}
      ]
    }
  },
  "aggs": {
    "timeline": {
      "date_histogram": {"field": "@timestamp", "interval": "hour"},
      "aggs": {
        "by_rule": {
          "terms": {"field": "rule.description", "size": 5}
        }
      }
    }
  }
}
```

### Kombinasi WAF + Domain Alert:

KQL:
```
(data.vhost : "domain1.ac.id" AND rule.groups : "attack") OR data.rule : (*)
```

Filter via Add Filter — buat 2 kondisi (OR logic di KQL):
```
(data.vhost : "domain1.ac.id" AND rule.groups : "attack") OR (exists:data.rule)
```
