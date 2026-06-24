# 05 — Wazuh Query Language (WQL) via API

WQL digunakan untuk query agent, groups, dan resource lain
langsung ke Wazuh Manager API (port 55000).

## 1. Autentikasi

Dapatkan token JWT:
```bash
TOKEN=$(curl -s -k -X POST "https://localhost:55000/security/user/authenticate" \
  -u wazuh:MyS3cur3P@ss! | python3 -c "import sys,json; print(json.load(sys.stdin)['data']['token'])")

echo "$TOKEN"
```

## 2. Daftar Semua Agent

```bash
curl -s -k -X GET "https://localhost:55000/agents?pretty=true" \
  -H "Authorization: Bearer $TOKEN"
```

## 3. WQL — Filter Agent by Status

### Agent active:
```bash
curl -s -k "https://localhost:55000/agents?q=status=Active&pretty=true" \
  -H "Authorization: Bearer $TOKEN"
```

### Agent disconnected:
```bash
curl -s -k "https://localhost:55000/agents?q=status=Disconnected&pretty=true" \
  -H "Authorization: Bearer $TOKEN"
```

### Agent by name:
```bash
curl -s -k "https://localhost:55000/agents?q=name=shared-hosting&pretty=true" \
  -H "Authorization: Bearer $TOKEN"
```

## 4. WQL — Filter by Group

### Agent dalam group tertentu:
```bash
curl -s -k "https://localhost:55000/agents?q=group=wordpress-hosting&pretty=true" \
  -H "Authorization: Bearer $TOKEN"
```

### Agent dalam default group:
```bash
curl -s -k "https://localhost:55000/agents?q=group=agent-group-0&pretty=true" \
  -H "Authorization: Bearer $TOKEN"
```

## 5. Detail Agent Spesifik

```bash
curl -s -k "https://localhost:55000/agents/002?pretty=true" \
  -H "Authorization: Bearer $TOKEN"
```

## 6. Daftar Groups

```bash
curl -s -k "https://localhost:55000/agents/groups?pretty=true" \
  -H "Authorization: Bearer $TOKEN"
```

## 7. Assign Agent ke Group

```bash
curl -s -k -X PUT \
  "https://localhost:55000/agents/002/group/wordpress-hosting?pretty=true" \
  -H "Authorization: Bearer $TOKEN"
```

## 8. WQL Operators

| Operator | Contoh | Keterangan |
|----------|--------|------------|
| `=` | `status=Active` | Exact match |
| `!=` | `status!=Active` | Not equal |
| `~` | `name~shared` | Like (wildcard) |
| `>` | `id>001` | Greater than |
| `<` | `id<010` | Less than |

### Kombinasi query:
```bash
curl -s -k "https://localhost:55000/agents?q=status=Active,name~shared&pretty=true" \
  -H "Authorization: Bearer $TOKEN"
```

## 9. WQL untuk FIM Events

Via API manager, query FIM events (syscheck):
```bash
curl -s -k "https://localhost:55000/syscheck/002?pretty=true" \
  -H "Authorization: Bearer $TOKEN"
```

## 10. Studi Kasus: Monitoring Agent

```bash
# Cek jumlah agent active
curl -s -k "https://localhost:55000/agents?q=status=Active" \
  -H "Authorization: Bearer $TOKEN" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(f'Active agents: {d[\"data\"][\"total_affected_items\"]}')"

# Cek versi agent
curl -s -k "https://localhost:55000/agents?pretty=true&select=id,name,version,status" \
  -H "Authorization: Bearer $TOKEN"
```
