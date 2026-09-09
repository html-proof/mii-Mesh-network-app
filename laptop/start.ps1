$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
Set-Location -LiteralPath $taskRoot
if (!(Test-Path .tools/ble-env/Scripts/python.exe)) {
    python -m venv .tools/ble-env
    .tools/ble-env/Scripts/python.exe -m pip install -r laptop/requirements.txt
    if ($LASTEXITCODE -ne 0) { throw 'Could not install Bluetooth dependencies' }
}
& .tools/ble-env/Scripts/python.exe laptop/companion.py
