param([switch]$UpdateGoldens, [string[]]$TestPaths = @())
$ErrorActionPreference = 'Stop'
$env:PATH = 'C:\Program Files\Git\mingw64\bin;' + $env:PATH
$taskRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $taskRoot
if (Test-Path pubspec_overrides.yaml) { throw 'Existing pubspec_overrides.yaml: refusing to replace it.' }
$taskPackageConfig = Get-Content .dart_tool/package_config.json -Raw | ConvertFrom-Json
$taskSodiumUri = ($taskPackageConfig.packages | Where-Object name -eq 'sodium').rootUri
$taskSodiumSource = ([Uri]$taskSodiumUri).LocalPath
$taskSodiumTarget = Join-Path $taskRoot '.tools/sodium-windows'
New-Item -ItemType Directory -Force $taskSodiumTarget | Out-Null
Copy-Item -Path (Join-Path $taskSodiumSource '*') -Destination $taskSodiumTarget -Recurse -Force
$taskArchive = Join-Path $taskRoot '.tools/libsodium-win.tar.gz'
if (!(Test-Path $taskArchive)) {
  Invoke-WebRequest 'https://download.libsodium.org/libsodium/releases/libsodium-1.0.22-mingw.tar.gz' -OutFile $taskArchive
}
if ((Get-FileHash $taskArchive -Algorithm SHA256).Hash.ToLower() -ne '1d99e0afaf27bce664249232e9dc628ae6bb7b49f0ab53ad6db372b028a35d9d') {
  throw 'Unexpected libsodium archive hash'
}
# This official release archive was also verified against libsodium's minisign
# public key. Use the genuine native binary when the Windows SDK is absent.
tar -xf $taskArchive -C .tools libsodium-win64/bin/libsodium-26.dll
Copy-Item .tools/libsodium-win64/bin/libsodium-26.dll (Join-Path $taskSodiumTarget '3rdparty/libsodium-test.dll') -Force
$taskHook = Join-Path $taskSodiumTarget 'hook/build.dart'
$taskHookText = Get-Content $taskHook -Raw
$taskInjection = @"
  if (config.targetOS == OS.windows) {
    output.assets.code.add(CodeAsset(package: 'sodium', name: 'libsodium',
      linkMode: DynamicLoadingBundled(),
      file: input.packageRoot.resolve('3rdparty/libsodium-test.dll')));
    return;
  }
  final builder =
"@
$taskHookText = $taskHookText.Replace('  final builder =', $taskInjection)
Set-Content $taskHook $taskHookText
try {
  @'
dependency_overrides:
  sodium:
    path: .tools/sodium-windows
'@ | Set-Content pubspec_overrides.yaml
  flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed' }
  if ($UpdateGoldens) { flutter test --timeout 60s --update-goldens @TestPaths } else { flutter test --timeout 60s @TestPaths }
  $taskTestExit = $LASTEXITCODE
} finally {
  Remove-Item -LiteralPath (Join-Path $taskRoot 'pubspec_overrides.yaml')
  flutter pub get
}
exit $taskTestExit


