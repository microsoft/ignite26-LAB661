# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Windows PowerShell port of infra/setup.sh for the Skillable VM.
# The bash script stays the source of truth. Keep the steps and messages in step with it.
#
# Provisions a Microsoft Foundry resource and project with gpt-5.4-mini and gpt-5.4,
# a Log Analytics workspace, Application Insights connected to the project, and the
# role assignments the live labs need. Safe to re-run: existing resources are reused.
# Writes .env for the live labs at the end. With -EnvOnly it creates nothing and only
# writes .env from the resources already in the resource group.
#
#   .\instructions\skillable\scripts\setup.ps1 -EnvOnly
#
# Optional environment variables skip the matching prompt:
#   SUBSCRIPTION_ID, RESOURCE_GROUP, LOCATION, FOUNDRY_NAME, PROJECT_NAME,
#   MINI_CAPACITY (default 500), MODEL_CAPACITY (default 100)
#
# Never prints keys or the Application Insights connection string.

[CmdletBinding()]
param([switch]$EnvOnly)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path

$models = @('gpt-5.4-mini', 'gpt-5.4')
# ASSERT generates test cases on gpt-5.4-mini with 8 parallel calls, so it needs more headroom.
$miniCapacity = if ($env:MINI_CAPACITY) { $env:MINI_CAPACITY } else { '500' }
$modelCapacity = if ($env:MODEL_CAPACITY) { $env:MODEL_CAPACITY } else { '100' }
$projectName = if ($env:PROJECT_NAME) { $env:PROJECT_NAME } else { 'lab661-project' }
$script:failed = New-Object System.Collections.Generic.List[string]

function Write-Log([string]$Message) { Write-Host ''; Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host '    ' -NoNewline; Write-Host 'OK  ' -ForegroundColor Green -NoNewline; Write-Host " $Message" }
function Write-Warn([string]$Message) { Write-Host '    ' -NoNewline; Write-Host 'WARN' -ForegroundColor Yellow -NoNewline; Write-Host " $Message" }
function Stop-Setup([string]$Message) { Write-Host '    ' -NoNewline; Write-Host 'FAIL' -ForegroundColor Red -NoNewline; Write-Host " $Message"; exit 1 }

# Returns the environment variable when set, otherwise prompts (with an optional default).
function Read-Value([string]$EnvName, [string]$Prompt, [string]$Default = '') {
    $current = [Environment]::GetEnvironmentVariable($EnvName)
    if ($current) { return $current }
    if ($Default) {
        $reply = Read-Host "    $Prompt [$Default]"
        if ($reply) { return $reply } else { return $Default }
    }
    $reply = Read-Host "    $Prompt"
    if (-not $reply) { Stop-Setup "$Prompt is required" }
    return $reply
}

# Runs az without letting stderr stop the script (Windows PowerShell 5.1 treats it as an error under 'Stop').
# Complex JMESPath (pipes, &, double quotes) is avoided: az.cmd and PowerShell 5.1 mangle them.
function Invoke-Az {
    $ErrorActionPreference = 'Continue'
    $all = & az @args 2>&1
    $ok = ($LASTEXITCODE -eq 0)
    $out = @($all | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" })
    $err = @($all | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] } | ForEach-Object { "$_" } | Where-Object { $_.Trim() })
    [pscustomobject]@{ Ok = $ok; Out = ($out -join "`n"); Err = ($err | Select-Object -First 1) }
}

# az prints "None" for a null value with -o tsv; treat it and failures as empty.
function Get-AzValue {
    $r = Invoke-Az @args -o tsv
    if (-not $r.Ok) { return '' }
    $value = $r.Out.Trim()
    if ($value -eq 'None') { return '' }
    return $value
}

function Get-AzJson {
    $r = Invoke-Az @args -o json
    if (-not $r.Ok -or -not $r.Out.Trim()) { return $null }
    return ($r.Out | ConvertFrom-Json)
}

function Test-Az { (Invoke-Az @args --output none).Ok }

# Creates the role assignment unless it exists.
function Set-Role([string]$Principal, [string]$Type, [string]$Role, [string]$Scope, [string]$Label) {
    $existing = @(Get-AzJson role assignment list --assignee $Principal --role $Role --scope $Scope --query '[].id')
    if ($existing.Count -gt 0) { Write-Ok "$Label (already assigned)"; return }
    $r = Invoke-Az role assignment create --assignee-object-id $Principal --assignee-principal-type $Type `
        --role $Role --scope $Scope --output none
    if ($r.Ok) { Write-Ok $Label }
    else { Write-Warn "$Label failed: $($r.Err)"; $script:failed.Add("role: $Label") }
}

# Writes a file readable only by the current user, UTF-8 without BOM.
function Write-PrivateFile([string]$Path, [string]$Content) {
    [System.IO.File]::WriteAllText($Path, $Content, (New-Object System.Text.UTF8Encoding($false)))
    if (-not (Get-Command icacls -ErrorAction SilentlyContinue)) { return }
    $ErrorActionPreference = 'Continue'
    & icacls $Path /inheritance:r /grant:r "$($env:USERNAME):(F)" *> $null
}

# ----------------------------------------------------------------- sign in ----
Write-Log 'Azure sign-in'
if (-not (Get-Command az -ErrorAction SilentlyContinue)) { Stop-Setup 'Azure CLI (az) not found' }
function Connect-Azure {
    # The device code prompt goes to stderr, so it must not stop the script.
    $ErrorActionPreference = 'Continue'
    & az login --use-device-code --output none
    if ($LASTEXITCODE -ne 0) { Stop-Setup 'az login failed' }
}
$signedInAs = Get-AzValue account show --query user.name
if ($signedInAs) {
    Write-Ok "signed in as $signedInAs"
    $reply = Read-Host '    Use this sign-in? [Y/n]'
    if ($reply -match '^[Nn]') { Connect-Azure }
}
else {
    Connect-Azure
}

# ------------------------------------------------------------ subscription ----
Write-Log 'Subscription'
$subscriptionId = $env:SUBSCRIPTION_ID
if (-not $subscriptionId) {
    $subs = @(Get-AzJson account list --query "[?state=='Enabled'].{name:name, id:id}")
    if ($subs.Count -eq 0) { Stop-Setup 'no enabled subscriptions found for this account' }
    if ($subs.Count -eq 1) {
        $subscriptionId = $subs[0].id
    }
    else {
        for ($i = 0; $i -lt $subs.Count; $i++) {
            Write-Host ('    {0,2}) {1}  ({2})' -f ($i + 1), $subs[$i].name, $subs[$i].id)
        }
        $choice = Read-Host "    Choose a subscription [1-$($subs.Count)]"
        $n = 0
        if (-not [int]::TryParse($choice, [ref]$n) -or $n -lt 1 -or $n -gt $subs.Count) { Stop-Setup 'invalid choice' }
        $subscriptionId = $subs[$n - 1].id
    }
}
$r = Invoke-Az account set --subscription $subscriptionId
if (-not $r.Ok) { Stop-Setup "could not select subscription ${subscriptionId}: $($r.Err)" }
Write-Ok "using $(Get-AzValue account show --query name) ($subscriptionId)"

# ------------------------------------------------- resource group, location ----
Write-Log 'Resource group and location'
$resourceGroup = Read-Value 'RESOURCE_GROUP' 'Resource group name' 'rg-lab661-foundry'
$location = if ($EnvOnly) { '' } else { Read-Value 'LOCATION' 'Azure location' 'eastus2' }

# Reuse a Foundry resource already in the group; otherwise pick a new unique name.
$foundryName = $env:FOUNDRY_NAME
if (-not $foundryName) {
    $foundryName = @(Get-AzJson cognitiveservices account list --resource-group $resourceGroup --query "[?kind=='AIServices'].name") |
        Select-Object -First 1
}
if (-not $foundryName) {
    if ($EnvOnly) { Stop-Setup "no Foundry resource found in resource group $resourceGroup" }
    $suffix = -join (1..3 | ForEach-Object { '{0:x2}' -f (Get-Random -Maximum 256) })
    $foundryName = Read-Value 'FOUNDRY_NAME' 'Foundry resource name (globally unique)' "lab661-foundry-$suffix"
}
$foundryName = $foundryName.ToLowerInvariant()
if ($foundryName -notmatch '^[a-z0-9]([a-z0-9-]{0,62}[a-z0-9])?$') {
    Stop-Setup 'Foundry resource name must be 2-64 letters, digits or hyphens, and not start or end with a hyphen'
}

$logsName = "log-$foundryName"
if ($logsName.Length -gt 63) { $logsName = $logsName.Substring(0, 63) }
$appiName = "appi-$foundryName"
$connectionName = 'appinsights'
$appiType = 'Microsoft.Insights/components'
$appiApi = '2020-02-02'
$accountLocation = ''
$appiConnectionString = ''

# Print the summary, stop on failures, then write .env from .env.example.
function Complete-Setup {
    $agentModel = ''
    foreach ($model in $models) {
        if (Test-Az cognitiveservices account deployment show --name $foundryName --resource-group $resourceGroup --deployment-name $model) {
            $agentModel = $model
            break
        }
    }
    if (-not $agentModel) { $script:failed.Add("model deployment: none of $($models -join ' ') found on $foundryName") }

    # Read the real OpenAI endpoint; fall back to the custom-domain form the resource was created with.
    $openaiEndpoint = ''
    $endpoints = Get-AzJson cognitiveservices account show --name $foundryName --resource-group $resourceGroup --query properties.endpoints
    if ($endpoints -and $endpoints.'OpenAI Language Model Instance API') {
        $openaiEndpoint = ([string]$endpoints.'OpenAI Language Model Instance API').TrimEnd('/')
    }
    if (-not $openaiEndpoint) { $openaiEndpoint = "https://$foundryName.openai.azure.com" }

    $deployments = @(Get-AzJson cognitiveservices account deployment list --name $foundryName --resource-group $resourceGroup --query '[].name')

    Write-Log 'Summary'
    Write-Host "    Foundry resource : $foundryName ($accountLocation)"
    Write-Host "    Project          : $projectName"
    Write-Host "    Project endpoint : https://$foundryName.services.ai.azure.com/api/projects/$projectName"
    Write-Host "    Deployments      : $($deployments -join ',')"
    Write-Host "    Log Analytics    : $logsName"
    Write-Host "    App Insights     : $appiName (project connection: $connectionName)"
    Write-Host @"

    Live settings for .env. No API key is needed: DevBot and ASSERT sign in with
    your az login identity.

      AZURE_API_BASE=$openaiEndpoint
      DEVBOT_MODE=live
      DEVBOT_MODEL=azure/$agentModel
      ASSERT_MODEL=azure/$agentModel
      ASSERT_AZURE_USE_AAD=1
      APPLICATIONINSIGHTS_CONNECTION_STRING=(written to .env, not printed)

    New role assignments can take a few minutes to apply. If the first live call
    returns 401 or 403, wait a few minutes and try again.
"@

    if ($script:failed.Count -gt 0) {
        Write-Host ''
        Write-Host "    $($script:failed.Count) item(s) not completed:" -ForegroundColor Red
        foreach ($item in $script:failed) { Write-Host "      - $item" }
        Write-Host ''
        exit 1
    }

    Write-Log 'Local environment'
    $envFile = Join-Path $repoRoot '.env'
    $writeEnv = $true
    if (Test-Path -LiteralPath $envFile) {
        $reply = Read-Host "    Replace existing .env with this lab's settings? [y/N]"
        if ($reply -notmatch '^[Yy]$') {
            $writeEnv = $false
            Write-Warn 'existing .env kept unchanged; verify its settings before using the live labs'
        }
    }
    if ($writeEnv) {
        # Single-quoted like the bash version (jq @sh) so dotenv reads the value literally.
        $quoted = "'" + ($appiConnectionString -replace "'", "'\''") + "'"
        $lines = foreach ($line in [System.IO.File]::ReadAllLines((Join-Path $repoRoot '.env.example'))) {
            if ($line.StartsWith('DEVBOT_MODE=')) { 'DEVBOT_MODE=live' }
            elseif ($line.StartsWith('AZURE_API_BASE=')) { "AZURE_API_BASE=$openaiEndpoint" }
            elseif ($line.StartsWith('DEVBOT_MODEL=')) { "DEVBOT_MODEL=azure/$agentModel" }
            elseif ($line.StartsWith('ASSERT_MODEL=')) { "ASSERT_MODEL=azure/$agentModel" }
            elseif ($line.StartsWith('ASSERT_AZURE_USE_AAD=')) { 'ASSERT_AZURE_USE_AAD=1' }
            elseif ($line.StartsWith('APPLICATIONINSIGHTS_CONNECTION_STRING=')) { "APPLICATIONINSIGHTS_CONNECTION_STRING=$quoted" }
            else { $line }
        }
        Write-PrivateFile $envFile (($lines -join "`n") + "`n")
        Write-Ok 'created .env for live mode with owner-only permissions; credentials not printed'
    }

    Write-Host ''
    if ($EnvOnly) { Write-Host '    Local environment is ready.' -ForegroundColor Green }
    else { Write-Host '    Foundry project, models, monitoring and access are ready.' -ForegroundColor Green }
    Write-Host ''
}

if ($EnvOnly) {
    Write-Log 'Existing resources'
    $accountLocation = Get-AzValue cognitiveservices account show --name $foundryName --resource-group $resourceGroup --query location
    if (-not $accountLocation) { Stop-Setup "Foundry resource $foundryName not found in $resourceGroup" }
    # Pre-provisioned labs may not follow this script's naming, so look these up.
    $appiName = @(Get-AzJson resource list --resource-group $resourceGroup --resource-type $appiType --query '[].name') | Select-Object -First 1
    if (-not $appiName) { Stop-Setup "no Application Insights found in $resourceGroup" }
    $logsName = @(Get-AzJson resource list --resource-group $resourceGroup --resource-type Microsoft.OperationalInsights/workspaces --query '[].name') |
        Select-Object -First 1
    $appiConnectionString = Get-AzValue resource show --resource-group $resourceGroup --name $appiName `
        --resource-type $appiType --api-version $appiApi --query properties.ConnectionString
    Write-Ok "found $foundryName and $appiName; nothing will be created"
    Complete-Setup
    exit 0
}

Write-Log 'Plan'
Write-Host "    Subscription     : $subscriptionId"
Write-Host "    Resource group   : $resourceGroup"
Write-Host "    Location         : $location"
Write-Host "    Foundry resource : $foundryName"
Write-Host "    Project          : $projectName"
Write-Host "    Models           : gpt-5.4-mini (${miniCapacity}K TPM), gpt-5.4 (${modelCapacity}K TPM)"
Write-Host "    Monitoring       : $logsName, $appiName (connected to the project)"
Write-Host '    Role assignments : Foundry User, Cognitive Services OpenAI User and Log Analytics Reader for you, Log Analytics Reader for the project identity'
$reply = Read-Host '    Create anything that is missing? [Y/n]'
if ($reply -match '^[Nn]') {
    Write-Host '    Cancelled. Nothing was created.'
    exit 0
}

# ------------------------------------------------------- resource provider ----
Write-Log 'Resource providers'
foreach ($namespace in 'Microsoft.CognitiveServices', 'Microsoft.Insights', 'Microsoft.OperationalInsights') {
    if ((Get-AzValue provider show --namespace $namespace --query registrationState) -ne 'Registered') {
        $r = Invoke-Az provider register --namespace $namespace --wait
        if (-not $r.Ok) { Stop-Setup "could not register ${namespace}: $($r.Err)" }
    }
    Write-Ok "$namespace is registered"
}

# ---------------------------------------------------------- resource group ----
Write-Log 'Resource group'
if ((Get-AzValue group exists --name $resourceGroup) -eq 'true') {
    Write-Ok "using existing group $resourceGroup"
}
else {
    $r = Invoke-Az group create --name $resourceGroup --location $location --output none
    if (-not $r.Ok) { Stop-Setup "could not create ${resourceGroup}: $($r.Err)" }
    Write-Ok "created $resourceGroup in $location"
}

# --------------------------------------------------------- foundry resource ----
Write-Log 'Foundry resource'
if (Test-Az cognitiveservices account show --name $foundryName --resource-group $resourceGroup) {
    Write-Ok "using existing resource $foundryName"
}
else {
    $r = Invoke-Az cognitiveservices account create `
        --name $foundryName `
        --resource-group $resourceGroup `
        --location $location `
        --kind AIServices `
        --sku S0 `
        --custom-domain $foundryName `
        --allow-project-management `
        --assign-identity `
        --yes `
        --output none
    if (-not $r.Ok) { Stop-Setup "could not create ${foundryName}: $($r.Err)" }
    Write-Ok "created $foundryName"
}
$accountLocation = Get-AzValue cognitiveservices account show --name $foundryName --resource-group $resourceGroup --query location

# ----------------------------------------------------------------- project ----
Write-Log 'Foundry project'
if (Test-Az cognitiveservices account project show --name $foundryName --resource-group $resourceGroup --project-name $projectName) {
    Write-Ok "using existing project $projectName"
}
else {
    $r = Invoke-Az cognitiveservices account project create `
        --name $foundryName `
        --resource-group $resourceGroup `
        --project-name $projectName `
        --location $accountLocation `
        --output none
    if (-not $r.Ok) { Stop-Setup "could not create ${projectName}: $($r.Err)" }
    Write-Ok "created $projectName"
}

# ------------------------------------------------------------------ models ----
foreach ($model in $models) {
    Write-Log "Model $model"
    if (Test-Az cognitiveservices account deployment show --name $foundryName --resource-group $resourceGroup --deployment-name $model) {
        Write-Ok "deployment $model already exists"
        continue
    }

    # Latest non-deprecated version this resource can deploy in its region (filtered here, not in JMESPath).
    $available = @(Get-AzJson cognitiveservices account list-models --name $foundryName --resource-group $resourceGroup)
    $version = $available |
        Where-Object { $_.name -eq $model -and $_.format -eq 'OpenAI' -and $_.lifecycleStatus -ne 'Deprecated' } |
        Sort-Object -Property version |
        Select-Object -Last 1 -ExpandProperty version
    if (-not $version) {
        Write-Warn "$model is not offered by $foundryName in $accountLocation; try another location"
        $script:failed.Add($model)
        continue
    }

    # SKU support varies by region and list-models does not report it reliably,
    # so try the broadest SKUs first and keep the last error for the warning.
    $deployedSku = ''
    $capacity = if ($model -eq 'gpt-5.4-mini') { $miniCapacity } else { $modelCapacity }
    foreach ($sku in 'GlobalStandard', 'DataZoneStandard', 'Standard') {
        $r = Invoke-Az cognitiveservices account deployment create `
            --name $foundryName `
            --resource-group $resourceGroup `
            --deployment-name $model `
            --model-name $model `
            --model-version $version `
            --model-format OpenAI `
            --sku-name $sku `
            --sku-capacity $capacity `
            --output none
        if ($r.Ok) { $deployedSku = $sku; break }
        Write-Warn "$model $version not deployed with ${sku}: $($r.Err)"
    }

    if ($deployedSku) {
        Write-Ok "deployed $model $version ($deployedSku, ${capacity}K TPM)"
    }
    else {
        Write-Warn "could not deploy $model in $accountLocation; try another location or check quota"
        $script:failed.Add($model)
    }
}

# -------------------------------------------------------------- monitoring ----
Write-Log 'Log Analytics workspace'
if (Test-Az monitor log-analytics workspace show --resource-group $resourceGroup --workspace-name $logsName) {
    Write-Ok "using existing workspace $logsName"
}
else {
    $r = Invoke-Az monitor log-analytics workspace create `
        --resource-group $resourceGroup `
        --workspace-name $logsName `
        --location $accountLocation `
        --retention-time 30 `
        --output none
    if (-not $r.Ok) { Stop-Setup "could not create ${logsName}: $($r.Err)" }
    Write-Ok "created $logsName"
}
$logsId = Get-AzValue monitor log-analytics workspace show --resource-group $resourceGroup --workspace-name $logsName --query id

Write-Log 'Application Insights'
if (Test-Az resource show --resource-group $resourceGroup --name $appiName --resource-type $appiType --api-version $appiApi) {
    Write-Ok "using existing $appiName"
}
else {
    # JSON goes through a file: Windows PowerShell 5.1 strips double quotes from native arguments.
    $propsFile = [System.IO.Path]::GetTempFileName()
    try {
        $props = @{ Application_Type = 'web'; WorkspaceResourceId = $logsId } | ConvertTo-Json -Compress
        Write-PrivateFile $propsFile $props
        $r = Invoke-Az resource create `
            --resource-group $resourceGroup `
            --name $appiName `
            --resource-type $appiType `
            --api-version $appiApi `
            --location $accountLocation `
            --properties "@$propsFile" `
            --output none
    }
    finally { Remove-Item -LiteralPath $propsFile -Force -ErrorAction SilentlyContinue }
    if (-not $r.Ok) { Stop-Setup "could not create ${appiName}: $($r.Err)" }
    Write-Ok "created $appiName, backed by $logsName"
}
$appiId = Get-AzValue resource show --resource-group $resourceGroup --name $appiName `
    --resource-type $appiType --api-version $appiApi --query id
$appiConnectionString = Get-AzValue resource show --resource-group $resourceGroup --name $appiName `
    --resource-type $appiType --api-version $appiApi --query properties.ConnectionString

# Connects the project to Application Insights so Foundry can show traces.
Write-Log 'Foundry project connection to Application Insights'
$connectionUri = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.CognitiveServices/accounts/$foundryName/projects/$projectName/connections/${connectionName}?api-version=2025-04-01-preview"
$connectionBody = [System.IO.Path]::GetTempFileName()
try {
    $body = @{
        properties = @{
            category      = 'AppInsights'
            target        = $appiId
            authType      = 'ApiKey'
            isSharedToAll = $true
            credentials   = @{ key = $appiConnectionString }
            metadata      = @{ ApiType = 'Azure'; ResourceId = $appiId }
        }
    } | ConvertTo-Json -Depth 5 -Compress
    Write-PrivateFile $connectionBody $body
    $r = Invoke-Az rest --method put --uri $connectionUri --body "@$connectionBody" --output none
}
finally { Remove-Item -LiteralPath $connectionBody -Force -ErrorAction SilentlyContinue }
if ($r.Ok) {
    Write-Ok "connected $projectName to $appiName as '$connectionName'"
}
else {
    Write-Warn "could not create the project connection: $($r.Err)"
    $script:failed.Add('project connection to Application Insights')
}

# ------------------------------------------------------------------- access ----
Write-Log 'Access (RBAC)'
$foundryUserRole = '53ca6127-db72-4b80-b1b0-d745d6d5456d'
$openaiUserRole = '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
$logAnalyticsReaderRole = '73c42c96-874c-492b-b04d-ab87d138a893'
$accountId = Get-AzValue cognitiveservices account show --name $foundryName --resource-group $resourceGroup --query id

$userOid = Get-AzValue ad signed-in-user show --query id
if ($userOid) {
    Set-Role $userOid User $foundryUserRole $accountId "Foundry User for you on $foundryName"
    Set-Role $userOid User $openaiUserRole $accountId "Cognitive Services OpenAI User for you on $foundryName"
    Set-Role $userOid User $logAnalyticsReaderRole $appiId "Log Analytics Reader for you on $appiName"
}
else {
    Write-Warn 'could not look up your user in Entra ID; skipping your role assignments'
    $script:failed.Add("role: your access to the models (ask an admin for Cognitive Services OpenAI User on $foundryName)")
}

$projectMi = Get-AzValue cognitiveservices account project show `
    --name $foundryName --resource-group $resourceGroup --project-name $projectName --query identity.principalId
if ($projectMi) {
    Set-Role $projectMi ServicePrincipal $logAnalyticsReaderRole $appiId "Log Analytics Reader for the project identity on $appiName"
}
else {
    Write-Warn 'the project has no managed identity; skipping its role assignment'
    $script:failed.Add('role: project identity')
}

Complete-Setup
