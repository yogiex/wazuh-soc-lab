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

## 5. Query MITRE ATT&CK (rule.mitre & data.attack_type)

Ada **2 cara** untuk query MITRE ATT&CK di Wazuh:

### 5a. rule.mitre.* — dari rule tags (semua source)

MITRE ATT&CK mapping dari tag `<mitre>` di rules (built-in + custom).
Disimpan sebagai **array** di `rule.mitre.technique`, `rule.mitre.tactic`, `rule.mitre.id`.

**KQL — cari alert dengan MITRE mapping:**
```
exists:rule.mitre.technique
```

**KQL — cari MITRE technique spesifik:**
```
rule.mitre.technique : "Web Shell"
rule.mitre.technique : "Exploit Public-Facing Application"
rule.mitre.technique : "Password Guessing"
```

**KQL — kombinasi tactic + domain:**
```
rule.mitre.tactic : "Persistence" AND data.vhost : "domain1.ac.id"
```

**Dev Tools — MITRE ID:**
```
GET wazuh-alerts-*/_search
{
  "query": {"term": {"rule.mitre.id": "T1505.003"}}
}
```

**Dev Tools — Aggregation unique technique:**
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "aggs": {
    "mitre_techniques": {
      "terms": {"field": "rule.mitre.technique", "size": 50}
    }
  }
}
```

### 5b. data.attack_type — dari syslog injector + ingest pipeline

Field `data.attack_type` muncul dari 2 sumber:
1. **Syslog (Sangfor / WAF):** injector langsung menulis `attack_type="SQL Injection"` → di-parse decoder
2. **Ingest pipeline:** OpenSearch otomatis copy `rule.mitre.technique[0]` → `data.attack_type` saat indexing

**KQL — cari attack_type langsung:**
```
data.attack_type : (*)
data.attack_type : "SQL Injection"
data.attack_type : "WebShell Upload"
data.attack_type : "Cross-Site Scripting"
```

**Kombinasi dengan filter lain:**
```
data.attack_type : "SQL Injection" AND data.srcip : "10.0.0.50"
data.attack_type : "WebShell Upload" AND data.actions : "blocked"
```

**Dev Tools — unique attack_type:**
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

### 5c. Perbandingan rule.mitre vs data.attack_type

| Aspek | `rule.mitre.technique` | `data.attack_type` |
|---|---|---|
| Sumber | Tag `<mitre>` di rules | Syslog injector + ingest pipeline |
| Tipe data | Array (bisa multi-value) | String (single value) |
| Cakupan | Semua alert (Apache, FIM, syslog) | Syslog Sangfor/WAF + pipeline-copy |
| Query | `rule.mitre.technique : "Web Shell"` | `data.attack_type : "Web Shell"` |
| Availability | Semua rule dengan MITRE tag | Perlu injector atau pipeline |

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
