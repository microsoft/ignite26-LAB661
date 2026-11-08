# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Loads .env into the current PowerShell session for More 0 and 1 on the Skillable VM.
# Dot-source it so the variables stay set:  . .\instructions\skillable\scripts\load-env.ps1
# Add -Live once to switch .env from offline to live mode first.
param([switch]$Live)

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$envPath = Join-Path $repoRoot '.env'
if (-not (Test-Path -LiteralPath $envPath)) {
    Write-Host '.env not found. Check the LAB661-Foundry-status.txt file on the desktop, or ask a proctor.' -ForegroundColor Red
    return
}

if ($Live) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $lines = [IO.File]::ReadAllLines($envPath) -replace '^DEVBOT_MODE=.*', 'DEVBOT_MODE=live'
    [IO.File]::WriteAllText($envPath, (($lines -join "`n") + "`n"), $utf8)
}

foreach ($line in [IO.File]::ReadAllLines($envPath)) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
        $name = $Matches[1]
        $value = $Matches[2].Trim()
        if ($value -match "^(['`"])(.*)\1$") { $value = $Matches[2] }
        Set-Item -Path "env:$name" -Value $value
    }
}
$env:PYTHONPATH = Join-Path $repoRoot 'src'

Write-Host "Loaded .env. DEVBOT_MODE=$env:DEVBOT_MODE"
