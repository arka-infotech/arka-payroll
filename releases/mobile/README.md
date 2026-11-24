# Mobile updates (Android)

Server folder (production):

```text
/root/releases/ArkaPayroll/updates/mobile/
  latest.json
  aips-release.apk
```

Public URL (nginx should alias this path):

```text
https://72.60.220.10/arka-payroll/updates/mobile/latest.json
https://72.60.220.10/arka-payroll/updates/mobile/aips-release.apk
```

## Publish a new build

```bash
# on build machine
cd frontend
flutter build apk --release

# on server
scp build/app/outputs/flutter-apk/app-release.apk \
  root@SERVER:/root/releases/ArkaPayroll/updates/mobile/aips-release.apk

# edit latest.json — versionCode MUST increase
nano /root/releases/ArkaPayroll/updates/mobile/latest.json
```

## nginx example

```nginx
location /arka-payroll/updates/mobile/ {
    alias /root/releases/ArkaPayroll/updates/mobile/;
    autoindex off;
    types { application/vnd.android.package-archive apk; }
    default_type application/octet-stream;
}
```

The app reads `latest.json`, downloads the APK, then opens **Android’s built-in package installer**.
