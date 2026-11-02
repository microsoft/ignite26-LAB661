# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Windows PowerShell port of src/scripts/run-offline-loop.sh for the Skillable VM.
# Runs the full ASSERT -> ACS protect loop end to end, offline and deterministic.
# The bash script stays the source of truth. Keep the stages in step with it.
#
#   .\instructions\skillable\scripts\run-offline-loop.ps1

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

$venvScripts = Join-Path $repoRoot '.venv\Scripts'
$python = if (Test-Path -LiteralPath (Join-Path $venvScripts 'python.exe')) { Join-Path $venvScripts 'python.exe' } else { 'python' }
$assertAi = if (Test-Path -LiteralPath (Join-Path $venvScripts 'assert-ai.exe')) { Join-Path $venvScripts 'assert-ai.exe' } else { 'assert-ai' }

function Write-Stage([string]$Title) { Write-Host ''; Write-Host "== $Title ==" -ForegroundColor White }

function Invoke-Step([string]$Command, [string[]]$Arguments) {
    # Windows PowerShell 5.1 turns native stderr into a terminating error under 'Stop'.
    $ErrorActionPreference = 'Continue'
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Step failed with exit code ${LASTEXITCODE}: $Command $($Arguments -join ' ')" }
}

$savedPythonPath = $env:PYTHONPATH
Push-Location $repoRoot
try {
    $env:PYTHONPATH = if ($savedPythonPath) { "src;$savedPythonPath" } else { 'src' }

    Write-Stage '1/5  Capture the baseline ASSERT run (real agent outputs + reference judge)'
    Invoke-Step $python @('src/eval/build_baseline_fixture.py')

    Write-Stage '2/5  Generate an ACS policy from the findings (offline, fake LM)'
    Invoke-Step $python @('src/policy/generate_offline.py')

    Write-Stage '3/5  Validate the policy blocks every known-bad output (OPA)'
    Invoke-Step $assertAi @(
        'acs', 'validate',
        '--manifest', 'artifacts/acs/contoso-devbot-shell-abuse-v1/manifest.yaml',
        '--run-dir', 'data/results/contoso-devbot-shell-abuse-v1/baseline-unguarded',
        '--require-block'
    )

    Write-Stage '4/5  Enforce at runtime with guard_target (benign allowed, unsafe blocked)'
    Invoke-Step $python @('src/policy/guard_demo.py')

    Write-Stage '5/5  Verify: attack success rate before vs after'
    Invoke-Step $python @('src/policy/verify_reeval.py')
}
finally {
    $env:PYTHONPATH = $savedPythonPath
    Pop-Location
}

Write-Host ''
Write-Host 'Loop complete.' -ForegroundColor Green -NoNewline
Write-Host ' ASSERT found the unsafe behavior; ACS now blocks it at runtime.'
