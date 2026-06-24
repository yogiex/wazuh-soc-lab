# 02 — KQL Syntax

KQL (Kibana Query Language) — bahasa query default di OpenSearch Dashboards.
Simple, intuitive, dan mendukung autocomplete.

Aktifkan KQL di dropdown **"Change query language"** (kanan query bar).

## 1. Basic Field:Value

```
field_name : value
```

**Contoh:**
```
agent.name : "shared-hosting"
data.vhost : "domain1.ac.id"
rule.id : 100020
```

> Value dengan spasi harus pakai tanda kutip `"..."`

## 2. Number & Range

```
rule.level >= 10
rule.level < 5
rule.level >= 7 AND rule.level <= 12
```

**Operators:**
| Simbol | Arti |
|--------|------|
| `:` | equals / contains |
| `>` | greater than |
| `>=` | greater or equal |
| `<` | less than |
| `<=` | less or equal |

## 3. Logical Operators

### AND — semua kondisi harus terpenuhi
```
agent.name : "shared-hosting" AND rule.level >= 10
```

### OR — salah satu kondisi terpenuhi
```
data.vhost : "domain1.ac.id" OR data.vhost : "domain2.ac.id"
```

### NOT / negasi
```
NOT agent.name : "multi-site"
```
Atau pakai tanda kurung:
```
data.vhost : "domain1.ac.id" AND NOT rule.level : 3
```

## 4. Parentheses — Grouping

```
(agent.name : "shared-hosting" OR agent.name : "multi-site") AND rule.level >= 10
```

Tanpa parentheses, prioritas: NOT > AND > OR

## 5. Wildcard

```
agent.name : shared*
data.vhost : "domain*.ac.id"
rule.id : 1000*
```

- `*` — zero or more characters
- `?` — single character

## 6. Exists / Not Exists

Cek apakah field memiliki nilai:

```
exists:data.attack_type
NOT exists:data.attack_type
```

## 7. Contoh Query untuk Lab

**Semua alert serangan ke domain1:**
```
data.vhost : "domain1.ac.id" AND rule.groups : "attack"
```

**FIM events (file integrity monitoring):**
```
rule.groups : "fim" AND syscheck.event : "added"
```

**Alert level tinggi dari shared-hosting:**
```
agent.name : "shared-hosting" AND rule.level >= 10
```

**Webshell atau SQLi dari IP tertentu:**
```
data.srcip : "10.0.0.110" OR data.srcip : "10.0.0.66"
```

**Semua web attack dalam seminggu:**
```
rule.groups : "attack" AND data.vhost : "domain*.ac.id"
```

## 8. Latihan

Coba query berikut di Discover dan observasi hasilnya:

1. `rule.level : 12` — alert paling kritis
2. `rule.groups : "fim"` — semua FIM event
5. `exists:rule.mitre.technique` — alert yang punya MITRE ATT&CK mapping
6. `data.attack_type : (*)` — alert dengan attack_type (dari syslog/ingest)
7. `@timestamp >= "now-1h"` — alert dalam 1 jam terakhir
8. `agent.name : "shared-hosting" AND syscheck.event : "modified"` — file modification
