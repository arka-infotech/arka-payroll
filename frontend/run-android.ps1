# Run the Android emulator build with env that avoids:
# 1) C: vs F: Kotlin incremental cache crash (PUB_CACHE on F:)
# 2) Cursor sandbox redirecting GRADLE_USER_HOME to an empty temp cache
$ErrorActionPreference = "Stop"

$env:PUB_CACHE = "F:\pub-cache"
$env:GRADLE_USER_HOME = Join-Path $env:USERPROFILE ".gradle"

New-Item -ItemType Directory -Force -Path $env:PUB_CACHE | Out-Null

Write-Host "PUB_CACHE=$env:PUB_CACHE"
Write-Host "GRADLE_USER_HOME=$env:GRADLE_USER_HOME"

Set-Location $PSScriptRoot
flutter pub get
if ($args.Count -eq 0) {
  flutter run
} else {
  flutter run @args
}
