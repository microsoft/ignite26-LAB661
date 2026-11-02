# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Windows PowerShell port of src/scripts/check-setup.sh for the Skillable VM.
# The bash script stays the source of truth. Keep the ok/MISS lines in step with it.
#
#   .\instructions\skillable\scripts\check-setup.ps1

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

$venvPython = Join-Path $repoRoot '.venv\Scripts\python.exe'
$python = if (Test-Path -LiteralPath $venvPython) { $venvPython } else { 'python' }
$script:fail = $false

function Write-Ok([string]$Message) { Write-Host '  ' -NoNewline; Write-Host 'ok  ' -ForegroundColor Green -NoNewline; Write-Host "  $Message" }
function Write-Miss([string]$Message) { Write-Host '  ' -NoNewline; Write-Host 'MISS' -ForegroundColor Red -NoNewline; Write-Host "  $Message"; $script:fail = $true }

function Test-Python([string]$Code) {
    # Windows PowerShell 5.1 turns native stderr into a terminating error under 'Stop'.
    $ErrorActionPreference = 'Continue'
    & $python -c $Code *> $null
    return $LASTEXITCODE -eq 0
}

Write-Host 'Checking Contoso DevBot ACS + ASSERT lab prerequisites'

if (Test-Path -LiteralPath $venvPython) {
    Write-Ok 'virtual environment .venv'
}
else {
    Write-Miss '.venv not found in the repository root  (prepare the VM image)'
}

# Lab commands call plain `python`, so the terminal must resolve it to .venv.
$pathPython = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1
if ($pathPython -and $pathPython.Source -eq $venvPython) {
    Write-Ok 'python on PATH is .venv'
}
else {
    Write-Miss 'python on PATH is not .venv  (open a new terminal in VS Code, or run .\.venv\Scripts\Activate.ps1)'
}

if (Test-Python 'import sys; raise SystemExit(0 if sys.version_info[:2] >= (3, 11) else 1)') {
    # No double quotes in -c code: Windows PowerShell 5.1 mangles them for native commands.
    Write-Ok "python $(& $python -c 'import sys; print(*sys.version_info[:2], sep=chr(46))')"
}
else {
    Write-Miss 'python 3.11+'
}

if (Test-Python 'import assert_ai.integrations.acs') {
    Write-Ok 'assert-ai with the acs integration is importable'
}
else {
    Write-Miss 'assert-ai[acs] not importable  (prepare the VM image)'
}

if (Test-Python 'import acs_generator') { Write-Ok 'acs-generator present' } else { Write-Miss 'acs-generator missing' }
if (Test-Python 'import agent_control_specification') { Write-Ok 'agent-control-specification present' } else { Write-Miss 'agent-control-specification missing' }

$opa = Get-Command opa -ErrorAction SilentlyContinue
if ($opa) {
    Write-Ok "opa on PATH ($((& $opa.Source version | Select-Object -First 1)))"
}
else {
    Write-Miss 'opa not on PATH  (prepare the VM image)'
}

if (Get-Command node -ErrorAction SilentlyContinue) {
    Write-Ok 'node on PATH'
}
else {
    Write-Miss 'node not on PATH  (prepare the VM image)'
}

$savedPythonPath = $env:PYTHONPATH
try {
    $env:PYTHONPATH = Join-Path $repoRoot 'src'
    if (Test-Python 'from devbot.agent import chat') {
        Write-Ok 'devbot agent importable (PYTHONPATH=src)'
    }
    else {
        Write-Miss 'devbot agent not importable'
    }
}
finally {
    $env:PYTHONPATH = $savedPythonPath
}

Write-Host ''
if (-not $script:fail) {
    Write-Host 'All checks passed. Run: .\instructions\skillable\scripts\run-offline-loop.ps1'
}
else {
    Write-Host 'Some checks failed. See docs/troubleshooting.md.'
    exit 1
}
