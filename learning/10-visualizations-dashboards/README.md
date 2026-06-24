# 10 — Visualizations & Dashboards

Membuat visualisasi dan dashboard dari query yang sudah dipelajari.

## 1. Saved Search (Discover)

Simpan query Discover untuk digunakan di Visualize.

**Cara:**
1. Buka **Discover**
2. Tulis query: `rule.groups : "attack"`
3. Atur kolom yang ditampilkan
4. Klik **"Save search"** → beri nama: `Attack Events`
5. Bisa diakses kembali via **"Open Saved Search"**

## 2. Visualize

### 2.1 Pie Chart — Distribusi Rule Level

1. Buka **Visualize** → **Create visualization** → **Pie**
2. Source: `wazuh-alerts-*`
3. Bucket: **Split slices** → **Terms** → `rule.level`
4. Size: 15 (untuk semua level 1-15)
5. Klik **Save** → nama: `Alert Distribution by Level`

### 2.2 Bar Chart — Top Attacker IPs

1. **Create visualization** → **Bar chart** → Vertical bar
2. Source: `wazuh-alerts-*`
3. Y-axis: **Count**
4. X-axis: **Terms** → `data.srcip` → Size: 10
5. **Save** → nama: `Top 10 Attacker IPs`

### 2.3 Line Chart — Timeline Serangan

1. **Create visualization** → **Line**
2. Source: `wazuh-alerts-*`
3. Y-axis: **Count**
4. X-axis: **Date Histogram** → `@timestamp` → Interval: Hourly
5. Split series: **Terms** → `rule.level`
6. **Save** → nama: `Attack Timeline`

### 2.4 Data Table — Detail Alert

1. **Create visualization** → **Data table**
2. Source: `wazuh-alerts-*`
3. Split rows: **Terms** → `@timestamp` (per hour)
4. Split rows: **Terms** → `data.vhost`
5. Metrics: **Count**
6. **Save** → nama: `Alert Details per Hour`

### 2.5 Metric — Total Alerts (24h)

1. **Create visualization** → **Metric**
2. Source: `wazuh-alerts-*`
3. Metric: **Count**
4. Filter: `@timestamp >= "now-24h"`
5. **Save** → nama: `Total Alerts 24h`

## 3. Dashboard

### 3.1 Buat Dashboard

1. Buka **Dashboards** → **Create dashboard**
2. Klik **"Add existing"**
3. Pilih saved visualizations yang sudah dibuat
4. Atur layout (drag & resize)
5. **Save** → nama: `Security Monitoring Overview`

### 3.2 Contoh Layout Dashboard

```
┌─────────────────────┬──────────────────────────────┐
│   Total Alerts 24h  │   Alert Distribution Level   │
│     [Metric]        │       [Pie Chart]             │
├─────────────────────┴──────────────────────────────┤
│                Attack Timeline                      │
│                  [Line Chart]                       │
├─────────────────────┬──────────────────────────────┤
│  Top 10 Attacker IP │  Alert Details per Hour      │
│    [Bar Chart]      │     [Data Table]              │
└─────────────────────┴──────────────────────────────┘
```

### 3.3 Panel Filters

Dashboard bisa ditambahkan filter global yang berlaku
ke semua panel:

1. Klik **"+ Add filter"** di toolbar dashboard
2. Contoh: `data.vhost : "domain1.ac.id"`
3. Semua panel akan otomatis terfilter

## 4. Reporting

Export dashboard sebagai PDF/CSV:

1. Buka dashboard
2. Klik **"Reporting"** → **"Create report"**
3. Pilih format: **PDF** atau **CSV**
4. Generate report

## 5. Studi Kasus: Build Security Dashboard

**Langkah-langkah:**

1. **Discover:** Save search `All Attacks` dengan query `rule.groups : "attack"`
2. **Visualize:**
   - Pie chart: `Alert by Domain` → terms `data.vhost`
   - Line chart: `Attack Timeline` → date_histogram per hour
   - Bar chart: `Top Rules` → terms `rule.id`
   - Metric: `Total Alerts` → count
   - Data table: `Recent Alerts` → latest 20 alerts in table
3. **Dashboard:** Gabung semua ke `SOC Monitoring`
4. **Filter:** Tambah filter `@timestamp >= "now-7d"` ke dashboard

Dengan dashboard ini, Anda bisa monitor:
- Berapa total serangan dalam 7 hari
- Domain mana yang paling sering diserang
- Rule mana yang paling sering trigger
- Timeline serangan per jam

## 6. Export & Share

- **PDF Report:** Dashboard → Reporting → Create → PDF
- **CSV Data:** Discover → klik **"Export"** → Formatted / Raw
- **Share Link:** Dashboard → **"Share"** → copy URL
- **Embedded:** Dashboard → **"Share"** → embed HTML/iframe
