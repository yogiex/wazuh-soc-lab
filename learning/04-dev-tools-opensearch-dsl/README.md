# 04 — OpenSearch Query DSL via Dev Tools

Query langsung ke OpenSearch API menggunakan Query DSL (JSON).
Bisa eksplorasi data mentah (`_source`) tanpa dibatasi UI Discover.

## 1. Akses Dev Tools

Wazuh Dashboard → menu samping → **Dev Tools**
atau buka: `https://localhost:5601/app/dev_tools#/console`

Dev Tools menggunakan user yang sedang login (kibanaserver atau admin).
Jika ada error permission, login sebagai `admin` / `MyStr0ngP@ssw0rd!`.

Atau via curl:
```bash
curl -s -k -u admin:MyStr0ngP@ssw0rd! "https://localhost:9200/wazuh-alerts-*/_search"
```

## 2. Basic _search

### Semua dokumen (max 10):
```
GET wazuh-alerts-*/_search
```

### Batasi jumlah dokumen:
```
GET wazuh-alerts-*/_search
{
  "size": 50,
  "query": {"match_all": {}}
}
```

## 3. Memilih Field Spesifik dengan _source

Gunakan `_source` untuk mengambil field tertentu saja
(tanpa field yang tidak diperlukan).

### _source sebagai array:
```
GET wazuh-alerts-*/_search
{
  "_source": ["rule.id", "rule.level", "rule.description", "data.vhost", "data.attack_type", "@timestamp"],
  "size": 20,
  "query": {"match_all": {}}
}
```

### _source dengan includes/excludes:
```
GET wazuh-alerts-*/_search
{
  "_source": {
    "includes": ["rule.*", "data.vhost", "data.attack_type", "agent.*"],
    "excludes": ["data.original_log"]
  },
  "size": 20,
  "query": {"match_all": {}}
}
```

### Tanpa _source sama sekali (hitung dokumen saja):
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "_source": false,
  "query": {"match_all": {}}
}
```

## 4. Match Query (full-text search)

Cocok untuk field teks (deskripsi, pesan):

```
GET wazuh-alerts-*/_search
{
  "query": {"match": {"rule.description": "webshell"}}
}
```

## 5. Term Query (exact match)

Cocok untuk field keyword (vhost, ip, id):

```
GET wazuh-alerts-*/_search
{
  "query": {"term": {"data.vhost": "domain1.ac.id"}}
}
```

## 6. Range Query

```
GET wazuh-alerts-*/_search
{
  "_source": ["rule.id", "rule.level", "rule.description"],
  "query": {
    "range": {
      "rule.level": {"gte": 10, "lte": 15}
    }
  }
}
```

Date range:
```
GET wazuh-alerts-*/_search
{
  "query": {
    "range": {
      "@timestamp": {
        "gte": "now-24h",
        "lte": "now"
      }
    }
  }
}
```

## 7. Bool Query (AND/OR/NOT)

### Must (AND):
```
GET wazuh-alerts-*/_search
{
  "query": {
    "bool": {
      "must": [
        {"term": {"data.vhost": "domain1.ac.id"}},
        {"range": {"rule.level": {"gte": 10}}}
      ]
    }
  }
}
```

### Should (OR):
```
GET wazuh-alerts-*/_search
{
  "query": {
    "bool": {
      "should": [
        {"term": {"data.vhost": "domain1.ac.id"}},
        {"term": {"data.vhost": "domain2.ac.id"}}
      ],
      "minimum_should_match": 1
    }
  }
}
```

### Must Not (NOT):
```
GET wazuh-alerts-*/_search
{
  "query": {
    "bool": {
      "must": [
        {"term": {"data.vhost": "domain1.ac.id"}}
      ],
      "must_not": [
        {"term": {"rule.level": 3}}
      ]
    }
  }
}
```

### Kombinasi lengkap:
```
GET wazuh-alerts-*/_search
{
  "_source": ["rule.id", "rule.level", "data.vhost", "data.srcip", "@timestamp"],
  "query": {
    "bool": {
      "must": [
        {"term": {"agent.name": "shared-hosting"}},
        {"range": {"rule.level": {"gte": 7}}}
      ],
      "should": [
        {"match": {"rule.description": "SQL"}},
        {"match": {"rule.description": "webshell"}}
      ],
      "minimum_should_match": 1,
      "filter": [
        {"term": {"data.vhost": "domain1.ac.id"}}
      ]
    }
  }
}
```

## 8. Exists Query

Cek apakah field memiliki nilai:
```
GET wazuh-alerts-*/_search
{
  "query": {
    "exists": {"field": "rule.mitre.technique"}
  }
}
```

## 9. Studi Kasus: Eksplorasi _source

**Tujuan:** Lihat struktur data mentah sebuah alert.

1. Buka Dev Tools
2. Jalankan:
```
GET wazuh-alerts-*/_search?size=1
```
3. Hasil akan menampilkan 1 dokumen lengkap dengan semua field `_source`
4. Perhatikan struktur:
   - `_source.rule` — detail rule (id, level, description, groups, mitre)
   - `_source.rule.mitre` — MITRE ATT&CK (id, tactic, technique — array)
   - `_source.data` — data spesifik (vhost, srcip, dstip, actions, attack_type, rule, method, uri)
   - `_source.agent` — informasi agent (id, name, version, os)
   - `_source.manager` — informasi manager

**MITRE ATT&CK query (via rule.mitre):**
```
GET wazuh-alerts-*/_search
{
  "query": {"term": {"rule.mitre.technique": "Web Shell"}}
}
```

**Attack type dari syslog (langsung di data.attack_type):**
```
GET wazuh-alerts-*/_search
{
  "query": {"term": {"data.attack_type": "SQL Injection"}}
}
```

**Contoh: Ambil semua unique MITRE technique:**
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
