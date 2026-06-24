# 09 — Aggregations & Statistics

Menggunakan OpenSearch aggregations untuk statistik, top N, dan tren.

## 1. Terms Aggregation — Top Values

Hitung dokumen per unique value.

### Top IP penyerang:
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "aggs": {
    "top_attackers": {
      "terms": {"field": "data.srcip", "size": 10}
    }
  }
}
```

### Top domain yang diserang:
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "aggs": {
    "top_domains": {
      "terms": {"field": "data.vhost", "size": 10}
    }
  }
}
```

### Top rule yang trigger:
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "aggs": {
    "top_rules": {
      "terms": {"field": "rule.id", "size": 10}
    }
  }
}
```

### Distribusi level keparahan:
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "aggs": {
    "by_level": {
      "terms": {"field": "rule.level", "size": 15}
    }
  }
}
```

## 2. Date Histogram — Timeline

Aggregasi berdasarkan waktu.

### Alert per jam:
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "aggs": {
    "per_hour": {
      "date_histogram": {"field": "@timestamp", "interval": "hour"}
    }
  }
}
```

### Alert per hari:
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "aggs": {
    "per_day": {
      "date_histogram": {"field": "@timestamp", "interval": "day"}
    }
  }
}
```

## 3. Nested Aggregations

Kombinasi date histogram + terms.

### Timeline per IP:
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "query": {"range": {"@timestamp": {"gte": "now-7d"}}},
  "aggs": {
    "per_hour": {
      "date_histogram": {"field": "@timestamp", "interval": "hour"},
      "aggs": {
        "top_ips": {"terms": {"field": "data.srcip", "size": 5}}
      }
    }
  }
}
```

### Timeline per domain:
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "query": {"range": {"@timestamp": {"gte": "now-24h"}}},
  "aggs": {
    "per_hour": {
      "date_histogram": {"field": "@timestamp", "interval": "hour"},
      "aggs": {
        "by_domain": {
          "terms": {"field": "data.vhost", "size": 5}
        }
      }
    }
  }
}
```

### Timeline per attack_type:
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "query": {"range": {"@timestamp": {"gte": "now-7d"}}},
  "aggs": {
    "per_day": {
      "date_histogram": {"field": "@timestamp", "interval": "day"},
      "aggs": {
        "by_attack": {
          "terms": {"field": "data.attack_type", "size": 10}
        }
      }
    }
  }
}
```

## 4. Cardinality — Unique Count

Hitung jumlah unique value.

### Total unique IP:
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "aggs": {
    "unique_ips": {
      "cardinality": {"field": "data.srcip"}
    }
  }
}
```

### Total unique domain:
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "aggs": {
    "unique_domains": {
      "cardinality": {"field": "data.vhost"}
    }
  }
}
```

## 5. Filters Aggregation

Hitung dokumen dalam bucket filter yang ditentukan.

### Count by severity level:
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "query": {"range": {"@timestamp": {"gte": "now-24h"}}},
  "aggs": {
    "severity": {
      "filters": {
        "filters": {
          "critical": {"range": {"rule.level": {"gte": 12}}},
          "high":     {"range": {"rule.level": {"gte": 10, "lt": 12}}},
          "medium":   {"range": {"rule.level": {"gte": 7, "lt": 10}}},
          "low":      {"range": {"rule.level": {"lt": 7}}}
        }
      }
    }
  }
}
```

## 6. Value Count

Hitung jumlah dokumen yang memiliki field tertentu.

```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "aggs": {
    "with_attack_type": {
      "value_count": {"field": "data.attack_type"}
    }
  }
}
```

## 7. Studi Kasus: Daily Security Report

**Tujuan:** Buat query untuk report harian:
- Total alerts dalam 24 jam
- Top 5 attacker IP
- Top 5 domain
- Distribusi severity

```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "query": {"range": {"@timestamp": {"gte": "now-24h"}}},
  "aggs": {
    "total_alerts": {"value_count": {"field": "_id"}},
    "top_attackers": {"terms": {"field": "data.srcip", "size": 5}},
    "top_domains": {"terms": {"field": "data.vhost", "size": 5}},
    "severity": {
      "range": {
        "field": "rule.level",
        "ranges": [
          {"key": "Critical (12-15)", "from": 12},
          {"key": "High (10-11)", "from": 10, "to": 12},
          {"key": "Medium (7-9)", "from": 7, "to": 10},
          {"key": "Low (1-6)", "to": 7}
        ]
      }
    }
  }
}
```
