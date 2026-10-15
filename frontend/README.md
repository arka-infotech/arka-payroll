# Arka Payroll — Flutter Client

Targets: **Web**, **macOS**, **Windows**, **Linux**.

## Setup

```bash
# From repo root — create platform folders if missing
cd frontend
flutter create --platforms=web,macos,windows,linux .
flutter pub get
flutter run -d chrome
```

Configure API base URL via `--dart-define`:

```bash
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1
```

## Features

- JWT login with secure token persistence (`shared_preferences`)
- HR Payroll Dashboard — grid to punch LOP / bonus / adjustments
- Employee slip list + PDF viewer / print (`printing` package)
