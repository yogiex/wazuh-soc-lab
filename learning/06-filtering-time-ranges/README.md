# 06 — Filtering & Time Ranges

Teknik filtering lanjutan: date math, custom time range, nested field.

## 1. Time Picker Options

Klik pojok kanan atas → **"Last 24 hours"**.

**Quick select:**
- `Last 15 minutes` — real-time monitoring
- `Last 1 hour` — insiden terbaru
- `Last 24 hours` — daily overview
- `Last 7 days` — weekly trend
- `Last 30 days` — monthly analysis
- `This year` — long-term

**Custom range:** Klik **"Absolute"** → pilih start & end date.

## 2. Date Math di Discover Query

Gunakan di KQL query bar:

```
@timestamp >= "now-1h"
@timestamp >= "now-7d"
@timestamp >= "now-30m"
@timestamp < "now"
```

**Kombinasi dengan filter lain:**
```
@timestamp >= "now-7d" AND rule.level >= 10 AND data.vhost : "domain1.ac.id"
```

**Date math units:**
| Unit | Arti |
|------|------|
| `now` | current time |
| `+1h` | plus 1 hour |
| `-30m` | minus 30 minutes |
| `-7d` | minus 7 days |
| `-1w` | minus 1 week |
| `-1M` | minus 1 month |
| `/d` | rounded to day |
| `/h` | rounded to hour |

**Contoh: sejak awal hari ini:**
```
@timestamp >= "now/d"
```

## 3. Date Math di Dev Tools

```
GET wazuh-alerts-*/_search
{
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now-7d",
        "lt": "now"
      }
    }
  }
}
```

**Round to day (sejak awal hari):**
```
GET wazuh-alerts-*/_search
{
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now/d",
        "lt": "now+1d/d"
      }
    }
  }
}
```

## 4. Nested Field Filtering

Filter berdasarkan field di dalam objek bertingkat.

**KQL:**
```
rule.description : "SQL Injection"
rule.groups : "attack"
```

**Dot notation untuk field bertingkat:**
```
rule.groups : "fim"
rule.mitre.id : "T1505.003"
```

**Di Dev Tools — nested field di _source:**
```
GET wazuh-alerts-*/_search
{
  "_source": ["rule.id", "rule.level", "rule.mitre"],
  "query": {
    "match": {"rule.groups": "fim"}
  }
}
```

## 5. Multiple Values (is one of)

KQL — pakai OR:
```
data.vhost : "domain1.ac.id" OR data.vhost : "domain2.ac.id"
```

Atau pakai Lucene regex:
```
data.vhost:/domain[12]\.ac\.id/
```

Add Filter → Operator `is one of`:
```
Field: data.vhost
Operator: is one of
Values: [domain1.ac.id] [domain2.ac.id]
```

## 6. Studi Kasus: Weekly Report

**Tujuan:** Lihat semua aktivitas serangan untuk semua domain
dalam 7 hari terakhir, level >= 7.

**KQL:**
```
@timestamp >= "now-7d" AND rule.level >= 7 AND data.vhost : "domain*.ac.id"
```

**Dev Tools time range query:**
```
GET wazuh-alerts-*/_search
{
  "_source": ["@timestamp", "rule.id", "rule.level", "data.vhost", "data.srcip"],
  "size": 100,
  "query": {
    "bool": {
      "must": [
        {"range": {"rule.level": {"gte": 7}}},
        {"range": {"@timestamp": {"gte": "now-7d", "lt": "now"}}},
        {"wildcard": {"data.vhost": "domain*.ac.id"}}
      ]
    }
  }
}
```
