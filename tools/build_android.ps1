$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $taskRoot
New-Item -ItemType Directory -Force .tools | Out-Null
if (!(Test-Path .tools/usr/bin/make.exe)) {
  Invoke-WebRequest 'https://repo.msys2.org/msys/x86_64/make-4.4.1-3-x86_64.pkg.tar.zst' -OutFile .tools/make.tar.zst
  tar -xf .tools/make.tar.zst -C .tools usr/bin/make.exe
}
$env:PATH = "$taskRoot\.tools\usr\bin;C:\Program Files\Git\bin;C:\Program Files\Git\usr\bin;" + $env:PATH
flutter build apk --debug --target-platform android-arm64
exit $LASTEXITCODE
