# 08 — FIM Integrity Monitoring

Query File Integrity Monitoring events: file added, modified, deleted.

## 1. Struktur FIM Event

FIM event memiliki field khusus `syscheck.*`:

```
_source
├── syscheck
│   ├── path        → Path file (/home/domain1.ac.id/public_html/shell.php)
│   ├── event       → added / modified / deleted
│   ├── size_after  → Ukuran file setelah perubahan
│   ├── perm_after  → Permission setelah perubahan
│   ├── md5_after   → MD5 hash setelah perubahan
│   ├── sha1_after  → SHA1 hash setelah perubahan
│   ├── sha256_after→ SHA256 hash setelah perubahan
│   └── uid         → User ID pemilik file
├── rule
│   ├── id          → 550 (added), 553 (modified), 554 (deleted)
│   │               → 100020 (webshell), 100021 (wp-config tamper)
│   └── groups      → fim, webshell, tamper, deletion
└── agent
    └── name        → shared-hosting
```

## 2. Cari FIM Events

**KQL — semua FIM:**
```
rule.groups : "fim"
```

**By event type:**
```
syscheck.event : "added"
syscheck.event : "modified"
syscheck.event : "deleted"
```

**Dev Tools:**
```
GET wazuh-alerts-*/_search
{
  "query": {"term": {"syscheck.event": "added"}}
}
```

## 3. Cari Webshell (new .php file)

Custom rule 100020 — file .php baru di webroot:

**KQL:**
```
rule.id : 100020
```

**Dev Tools — path spesifik:**
```
GET wazuh-alerts-*/_search
{
  "query": {
    "regexp": {"syscheck.path": "/home/domain.*\\.php"}
  }
}
```

**KQL — path mengandung "shell":**
```
syscheck.path : "*shell*.php"
```

## 4. Cari File Tamper

**wp-config.php modified (rule 100021):**
```
rule.id : 100021
```

**.htaccess modified (rule 100022):**
```
rule.id : 100022
```

**PHP file modified (rule 100023):**
```
rule.id : 100023
```

**File deleted (rule 100024):**
```
rule.id : 100024
```

**Kombinasi — semua file tamper:**
```
rule.id : 100021 OR rule.id : 100022 OR rule.id : 100023 OR rule.id : 100024
```

## 5. Query by Path

**KQL:**
```
syscheck.path : "/home/domain1.ac.id/public_html/shell1.php"
syscheck.path : "*shell*"
syscheck.path : "*/wp-config.php"
syscheck.path : "*.php"
```

**Dev Tools — wildcard:**
```
GET wazuh-alerts-*/_search
{
  "query": {
    "wildcard": {"syscheck.path": "*.php"}
  }
}
```

**Regex:**
```
GET wazuh-alerts-*/_search
{
  "query": {
    "regexp": {"syscheck.path": ".*shell.*\\.php"}
  }
}
```

## 6. Query by Hash

Cari file yang specific hash-nya berubah:

**Dev Tools:**
```
GET wazuh-alerts-*/_search
{
  "query": {"term": {"syscheck.sha256_after": "abc123..."}}
}
```

## 7. Studi Kasus: Investigasi Webshell

**Tujuan:** Investigasi indikasi webshell di `domain1.ac.id`.

**Step 1 — Cari semua FIM event:**
```
rule.groups : "fim" AND data.vhost : "domain1.ac.id"
```

**Step 2 — Filter file .php baru:**
```
rule.id : 100020 AND data.vhost : "domain1.ac.id"
```

**Step 3 — Lihat detail file:**
```
GET wazuh-alerts-*/_search
{
  "query": {"term": {"rule.id": "100020"}},
  "_source": ["syscheck.path", "syscheck.event", "syscheck.size_after", "@timestamp", "agent.name"]
}
```

**Step 4 — Timeline perubahan:**
```
GET wazuh-alerts-*/_search
{
  "size": 0,
  "query": {"term": {"rule.id": "100020"}},
  "aggs": {
    "timeline": {
      "date_histogram": {"field": "@timestamp", "interval": "hour"}
    }
  }
}
```
