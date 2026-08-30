# ProfitShield Web (Flutter)

Flutter web client for the DMS / ProfitShield backend.

## Features

- Login screen matching the ProfitShield navy/gold design (PAN or admin username)
- Responsive dashboard with:
  - 5 KPI cards
  - Documents by Category (donut)
  - Documents Trend last 7 days (line)
  - Top clients table
- Sidebar navigation (collapses to drawer on tablet/mobile)
- JWT auth with refresh + remember me

## Setup

```bash
cd profit_shield_web
flutter pub get
```

Default API (UAT): `https://profitshield.profygen.com/api/v1`

Override for local backend:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:5000/api/v1
```

## Default admin credentials

| Field | Value |
|-------|--------|
| Username | `admin` |
| Password | `Admin@123` |

Clients sign in with their PAN number.

## Project structure

```
lib/
  core/           # config, theme, API client, responsive helpers
  features/
    auth/         # login + auth state
    dashboard/    # KPIs, charts, table, sidebar
```
