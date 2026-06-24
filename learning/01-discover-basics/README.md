# 01 — Discover Basics

Navigasi halaman Discover untuk eksplorasi log Wazuh alerts.

## 1. Akses Halaman

Wazuh Dashboard → menu samping kiri → **Discover**
atau buka langsung: `https://localhost:5601/app/data-explorer/discover`

## 2. Time Picker

Pojok kanan atas → klik **"Last 24 hours"** untuk mengatur rentang waktu.

Pilihan umum:
- `Last 15 minutes`
- `Last 1 hour`
- `Last 24 hours`
- `Last 7 days`
- `Custom range` — pilih tanggal mulai & selesai

## 3. Field Sidebar (Panel Kiri)

Panel kiri menampilkan semua field dari index pattern `wazuh-alerts-*`.

### 3.1 Search Field

```
🔍 Search field names
```
Ketik nama field untuk mencari, contoh: `vhost`, `attack`, `rule.level`

### 3.2 Selected Fields

Field yang sedang ditampilkan sebagai kolom di tabel hasil.

Default: `_source` (semua field dalam satu kolom).

**Cara customize kolom:**
- Hover field di Available → klik **+** untuk menambah kolom
- Drag field dari Available ke area kolom
- Klik **×** di Selected untuk menghapus kolom
- Klik **"Unknown field _source"** lalu drag keluar untuk hide _source

**Contoh kolom yang berguna:**
```
📌 Selected fields
   ✓ data.vhost         ← domain yang diserang
   ✓ rule.id            ← ID rule yang trigger
   ✓ rule.level         ← level keparahan
   ✓ data.srcip         ← IP penyerang
   ✓ rule.description   ← deskripsi alert
```

### 3.3 Available Fields

Daftar semua field yang tersedia di index pattern. Klik salah satu field
untuk melihat detail: tipe data, nilai contoh, persentase dokumen yang
memiliki field tersebut.

**Field penting untuk Wazuh alerts:**

| Field | Tipe | Kegunaan |
|-------|------|----------|
| `agent.name` | string | Filter berdasarkan agent (shared-hosting, multi-site) |
| `agent.id` | string | ID agent (001, 002) |
| `rule.id` | string | Nomor rule yang trigger |
| `rule.level` | number | Level keparahan (1-15) |
| `rule.description` | string | Deskripsi alert |
| `rule.groups` | string | Grup rule (attack, fim, recon) |
| `data.vhost` | string | Domain (domain1.ac.id, labs.ac.id) |
| `data.srcip` | string | IP sumber serangan |
| `data.attack_type` | string | MITRE ATT&CK tipe serangan |
| `syscheck.path` | string | Path file yang dimonitor FIM |
| `syscheck.event` | string | Event FIM (added, modified, deleted) |
| `@timestamp` | date | Waktu kejadian |

## 4. Query Bar

Search bar di bagian atas untuk menulis query KQL (default) atau Lucene.

**Contoh KQL:**
```
agent.name : "shared-hosting"
rule.level >= 10
data.vhost : "domain1.ac.id"
```

Tekan **Enter** atau klik **Submit** (panah) untuk menjalankan.

## 5. Add Filter

Tombol **"+ Add Filter"** di sebelah kiri query bar untuk filter visual.

### 5.1 Cara Pakai

1. Klik **"+ Add Filter"**
2. Muncul dialog **"Edit filter"**

```
┌──────────────────────────────────────────┐
│  Edit filter                             │
│                                          │
│  Field:   [data.vhost            ▾]     │
│  Operator:[is                    ▾]     │
│  Value:   [domain1.ac.id         ]      │
│                                          │
│  ☐ Create custom label?                 │
│                                          │
│  [Save]  [Cancel]                        │
└──────────────────────────────────────────┘
```

3. Pilih **Field** dari dropdown (ketik untuk search)
4. Pilih **Operator**:
   - `is` / `is not` — exact match
   - `exists` — field ada nilainya
   - `does not exist` — field kosong
   - `is between` — range angka
   - `is one of` — multiple values
5. Isi **Value**
6. Klik **Save**

### 5.2 Negate / Exclude

Klik ikon **⊘** (exclude) pada filter yang sudah disave
untuk membalikkan kondisi (NOT).

### 5.3 Pin Filter

Klik ikon **📌** (pin) agar filter tetap berlaku saat
berpindah halaman (Discover → Dashboard → Visualize).

### 5.4 Disable / Remove

- Klik **checkbox** di filter untuk disable sementara
- Klik **×** untuk hapus filter

## 6. Edit as Query DSL

Di dalam dialog **Add Filter**, ada tombol **"Edit as Query DSL"**
yang mengubah filter visual menjadi kode OpenSearch Query DSL.

### 6.1 Cara Pakai

1. Klik **"+ Add Filter"**
2. Klik **"Edit as Query DSL"**

```
┌──────────────────────────────────────────┐
│  Edit filter                             │
│                                          │
│  [+] Edit as Query DSL   ←─── klik      │
│                                          │
│  OpenSearch Query DSL:                   │
│  ┌──────────────────────────────────────┐│
│  │ {"term": {"data.vhost":              ││
│  │   "domain1.ac.id"}}                  ││
│  └──────────────────────────────────────┘│
│                                          │
│  [Save]  [Cancel]                        │
└──────────────────────────────────────────┘
```

3. Tulis query DSL di textarea
4. Tekan **Escape** untuk selesai edit
5. Klik **Save**

### 6.2 Contoh Query DSL untuk Filter

**Term filter:**
```json
{"term": {"data.vhost": "domain1.ac.id"}}
```

**Range filter:**
```json
{"range": {"rule.level": {"gte": 10}}}
```

**Bool (AND):**
```json
{"bool": {"must": [
  {"term": {"data.vhost": "domain1.ac.id"}},
  {"range": {"rule.level": {"gte": 10}}}
]}}
```

**Exists filter:**
```json
{"exists": {"field": "data.attack_type"}}
```

## 7. Filter Management

Setelah filter disave, tampil di atas tabel sebagai badge:

```
data.vhost: domain1.ac.id
[×] [⊘] [checkbox aktif] [📌]
                  disable    pin
```

- **Hover** badge → lihat detail
- **Klik badge** → edit filter
- **Toggle checkbox** → disable/enable
- **×** → remove
- **⊘** → exclude (NOT)
- **📌** → pin across pages

Kombinasi beberapa filter menggunakan logika **AND**.
Bisa juga dikombinasi dengan KQL di query bar.

## 8. Studi Kasus: Filter Domain Spesifik

**Tujuan:** Tampilkan semua alert untuk `domain1.ac.id` dalam 7 hari.

1. Buka **Discover**
2. Time picker → **"Last 7 days"**
3. Klik **"+ Add Filter"**
4. Field: `data.vhost`, Operator: `is`, Value: `domain1.ac.id`
5. **Save**
6. (Optional) Klik **"Edit as Query DSL"** → lihat JSON yang terbentuk
7. Observasi tabel hasil

**KQL equivalent:**
```
data.vhost : "domain1.ac.id"
```

**Study kasus lanjutan — alert level tinggi:**
Filter: `data.vhost : "domain1.ac.id"` AND `rule.level >= 10`

KQL:
```
data.vhost : "domain1.ac.id" AND rule.level >= 10
```

Atau via Add Filter: buat 2 filter (vhost + range rule.level).
