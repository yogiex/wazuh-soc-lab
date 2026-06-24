# 03 — Lucene Syntax

Lucene query — alternatif KQL dengan fitur lebih kompleks.
Aktifkan via dropdown language selector → **Lucene**.

## 1. Basic Field:Value

```
field:value
```

**Contoh:**
```
agent.name:shared-hosting
data.vhost:domain1.ac.id
```

> Value tanpa spasi tidak perlu kutip.
> Value dengan spasi pakai `"..."`

## 2. Wildcard

```
agent.name:shared-*
data.vhost:domain?.ac.id
rule.id:1000*
```

- `*` — zero or more characters
- `?` — single character

## 3. Regex

```
data.vhost:/domain\d\.ac\.id/
rule.description:/webshell|backdoor/i
```

Format: `/pattern/flags`
- `i` — case insensitive
- Contoh: `/sql|sqli|union/i`

## 4. Fuzziness

Cari dengan toleransi typo/salah ketik (Levenshtein distance):

```
data.vhost:domain1~1
data.srcip:10.0.0.10~2
```

`~N` = maksimal N karakter yang boleh berbeda

## 5. Proximity

Cari kata yang berjarak tertentu dalam satu field:

```
rule.description:"wp config"~5
```

Artinya: kata "wp" dan "config" berjarak maksimal 5 posisi.

## 6. Range

```
rule.level:[7 TO 12]
@timestamp:[now-7d TO now]
```

- `[TO]` — inclusive
- `{TO}` — exclusive
- hybrid: `[7 TO 12}`

## 7. Boosting

Tingkatkan/menurunkan relevansi:

```
data.vhost:domain1^2 OR data.srcip:10.0.0.110
```

`^2` — field pertama 2× lebih relevan.

## 8. Logical Operators

```
+agent.name:shared-hosting +rule.level:>=10
```

- `+` — AND (wajib ada)
- `-` — NOT (tidak boleh ada)
- tanpa simbol — OR (opsional)

**Contoh kombinasi:**
```
+data.vhost:domain1.ac.id +rule.level:>=10
+data.vhost:domain1.ac.id -rule.level:3
(data.vhost:domain1.ac.id OR data.vhost:domain2.ac.id) +rule.level:12
```

## 9. Perbandingan KQL vs Lucene

| Fitur | KQL | Lucene |
|-------|-----|--------|
| Syntax | `field : value` | `field:value` |
| AND | `AND` | `+` |
| OR | `OR` | tanpa simbol |
| NOT | `NOT` atau `AND NOT` | `-` |
| Wildcard | `*`, `?` | `*`, `?` |
| Regex | ❌ | ✅ `/pattern/` |
| Fuzzy | ❌ | ✅ `~N` |
| Proximity | ❌ | ✅ `"a b"~N` |
| Boost | ❌ | ✅ `^N` |
| Parentheses | ✅ `(...)` | ✅ `(...)` |
| Range | `>=`, `<=` | `[TO]`, `{TO}` |
| Autocomplete | ✅ | partial |
| Recommended | ✅ (umum) | advanced use |
