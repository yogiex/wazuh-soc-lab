# 11 — Parasite SEO Detection

Mendeteksi **SEO Cloaking / Parasite SEO** di shared hosting WordPress
menggunakan Wazuh SIEM. Serangan ini memodifikasi `index.php` untuk
menyajikan konten judi online hanya kepada Googlebot.

## 1. Attack Pattern

```
index.php → deteksi User-Agent → jika Googlebot → include security.php
                              → jika user biasa → require wp-blog-header.php (normal)
```

**File anomali yang terdeteksi:**
- `index.php` — dimodifikasi (cloak engine)
- `indexx.php` — backup original (kadang backdoor)
- `security.php` — konten gambling
- `wp-config.php` — kadang disisipi eval backdoor

## 2. Deteksi Modifikasi index.php (FIM)

**KQL — cari perubahan index.php via FIM:**
```
syscheck.path : "index.php" AND rule.id : "553"
```

**KQL — cari perubahan index.php + wp-config.php:**
```
syscheck.path : "index.php" OR syscheck.path : "wp-config.php"
```

**Dev Tools — timeline perubahan file kritis:**
```
GET wazuh-alerts-*/_search
{
  "size": 20,
  "query": {
    "bool": {
      "filter": [
        { "terms": { "syscheck.path": ["/home/domain1.ac.id/public_html/index.php", "/home/domain1.ac.id/public_html/wp-config.php"] } },
        { "terms": { "rule.id": ["553", "550"] } }
      ]
    }
  },
  "sort": [{ "@timestamp": "desc" }],
  "_source": ["@timestamp", "syscheck.path", "rule.id", "syscheck.event"]
}
```

## 3. Deteksi File Security.php Baru

**KQL — cari file security.php (indikasi konten judi):**
```
syscheck.path : "security.php"
```

**KQL — cari varian index file mencurigakan:**
```
syscheck.path : "indexx.php" OR syscheck.path : "index.php.bak"
```

**Dev Tools — aggregasi lokasi file anomali:**
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "query": {
    "bool": {
      "filter": [
        { "terms": { "rule.id": ["100030", "100031", "100032"] } }
      ]
    }
  },
  "aggs": {
    "file_patterns": {
      "terms": { "field": "syscheck.path", "size": 50 }
    }
  }
}
```

## 4. Deteksi Googlebot Crawl ke Path Mencurigakan

Dari Apache access log yang dimonitoring Wazuh agent:

**KQL — Googlebot akses path mencurigakan:**
```
data.ua : "*Googlebot*" AND (data.uri : "/data-alumni" OR data.uri : "/security")
```

**KQL — perbandingan response size Googlebot vs user biasa:**
```
(data.ua : "*Googlebot*" AND data.uri : "/") OR (data.ua : "*Chrome*" AND data.uri : "/")
```

**Dev Tools — aggregasi User-Agent + URI:**
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "query": {
    "match": { "data.vhost": "domain1.ac.id" }
  },
  "aggs": {
    "by_ua": {
      "terms": { "field": "data.ua", "size": 10 },
      "aggs": {
        "by_uri": {
          "terms": { "field": "data.uri", "size": 10 }
        }
      }
    }
  }
}
```

## 5. Forensik Timeline Multi-Source

Rekonstruksi urutan serangan: Recon → Exploit → Cloak → Crawl.

**KQL — semua aktivitas SEO cloaking dalam timeline:**
```
rule.id : "100030" OR rule.id : "100031" OR rule.id : "100032" OR rule.id : "100034" OR rule.id : "100035"
```

**Dev Tools — full timeline reconstruction:**
```
GET wazuh-alerts-*/_search
{
  "size": 50,
  "query": {
    "bool": {
      "should": [
        { "terms": { "rule.id": ["100030", "100031", "100032", "100033", "100034", "100035"] } },
        { "term": { "rule.id": "100020" } },
        { "term": { "rule.id": "550" } }
      ],
      "minimum_should_match": 1
    }
  },
  "sort": [{ "@timestamp": "asc" }],
  "_source": ["@timestamp", "rule.id", "rule.description", "syscheck.path", "data.ua", "data.uri"]
}
```

## 6. Aggregasi — Top Attack Indicators

**Top 10 file yang paling sering berubah (indikasi kompromi):**
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "query": {
    "terms": { "rule.id": ["553", "550"] }
  },
  "aggs": {
    "top_files": {
      "terms": { "field": "syscheck.path", "size": 10 }
    }
  }
}
```

**Distribusi event berdasarkan agent + rule:**
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "query": {
    "terms": { "rule.id": ["100030", "100031", "100032", "100033"] }
  },
  "aggs": {
    "by_agent": {
      "terms": { "field": "agent.name", "size": 10 },
      "aggs": {
        "by_rule": {
          "terms": { "field": "rule.id", "size": 10 }
        }
      }
    }
  }
}
```

## 7. Studi Kasus: Analisis Cloaking

**Skenario:** Sebuah shared hosting WordPress (5 domain) terkompromi.
Penyerang memodifikasi `index.php` untuk cloaking ke Googlebot dan
membuat `security.php` berisi konten deface "deface seo cloaking".

**Langkah Investigasi di Wazuh Dashboard:**

```
Langkah 1: Cek alert FIM — file apa saja yang berubah?
  → syscheck.path : (*) AND rule.id : "553"
  → Filter: timeframe 24h

Langkah 2: Apakah ada index.php yang berubah?
  → syscheck.path : "index.php" AND rule.id : "553"

Langkah 3: Apakah ada file baru mencurigakan?
  → syscheck.path : "security.php" OR syscheck.path : "indexx.php"

Langkah 4: Apakah wp-config.php ikut berubah?
  → syscheck.path : "wp-config.php" AND rule.id : "553"

Langkah 5: Apakah ada akses Googlebot ke path aneh?
  → data.ua : "*Googlebot*"

Langkah 6: Agregasi timeline serangan
  → (rule.id : "100030" OR rule.id : "100031" OR rule.id : "100034")
  → Sort by @timestamp asc
```

**Interpretasi Hasil:**

| Temuan | Indikasi |
|--------|----------|
| `index.php` modified + `security.php` created | ✅ SEO Cloaking confirmed |
| Googlebot crawl → `/security.php` | ✅ Konten judi sudah terindeks |
| `shell.php` di uploads | ✅ Initial compromise via webshell |
| `wp-config.php` modified | ✅ Backdoor persistence |
| Multiple files change dalam 1 jam | ✅ Automated attack campaign |

## 8. Referensi

- [Case Study: SEO Cloaking Parasite](../docs/CASE-STUDY-SEO-CLOAKING.md)
- [Wazuh FIM Documentation](https://documentation.wazuh.com/current/user-manual/capabilities/file-integrity/index.html)
- [Panduan Penanganan Defacement Judi Online — EduCSIRT](https://educsirt.kemendikdasmen.go.id/assets/panduan/Panduan_Penanganan_Insiden_Web_Defacement_Judi_Online.pdf)
