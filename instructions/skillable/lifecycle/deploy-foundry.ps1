# Skillable lifecycle action for LAB661.
# Execute Script in Virtual Machine > PowerShell. Event: First Displayable. Blocking: off, because
# the core labs are offline. Timeout: 30 minutes. Retries: 0. Error Action: Log.
# Deploys infra/main.bicep into the lab resource group, then writes .env in offline mode for
# More 0 and 1. Progress and errors go to LAB661-Foundry-status.txt on the desktop.
$ErrorActionPreference = 'Stop'
$repoRoot = 'C:\Users\LabUser\Desktop\LAB661'
$statusPath = 'C:\Users\LabUser\Desktop\LAB661-Foundry-status.txt'

$tenantId = '@lab.CloudSubscription.TenantId'
$subscriptionId = '@lab.CloudSubscription.Id'
$clientId = '@lab.CloudSubscription.AppId'
$clientSecret = '@lab.CloudSubscription.AppSecret'
$resourceGroup = '@lab.CloudResourceGroup(ResourceGroup1).Name'
# Built in two parts so Skillable does not replace it.
$tokenPrefix = '@' + 'lab.'

$utf8 = New-Object System.Text.UTF8Encoding($false)
function Write-Status([string]$Text) {
    [IO.File]::WriteAllText($statusPath, "LAB661 Foundry setup`r`n$Text`r`n", $utf8)
}

# Runs az, throws with its error text on failure, and returns only stdout.
function Invoke-Az {
    $ErrorActionPreference = 'Continue'
    $output = & az @args 2>&1
    $errors = $output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
    if ($LASTEXITCODE -ne 0) {
        $message = (($errors | Out-String).Trim()).Replace($clientSecret, '[redacted]')
        throw "az $($args[0]) $($args[1]) failed: $message"
    }
    $output | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] }
}

# A private Azure CLI profile keeps the service principal sign-in away from the learner's az login.
$configDir = Join-Path $env:TEMP ("lab661-az-" + [guid]::NewGuid())
$previousConfigDir = $env:AZURE_CONFIG_DIR

try {
    Write-Status 'Result: RUNNING'
    $inputs = @{ TenantId = $tenantId; SubscriptionId = $subscriptionId; AppId = $clientId
        AppSecret = $clientSecret; ResourceGroup = $resourceGroup }
    foreach ($key in $inputs.Keys) {
        if ([string]::IsNullOrWhiteSpace($inputs[$key]) -or $inputs[$key].StartsWith($tokenPrefix)) {
            throw "Skillable did not supply $key."
        }
    }

    $env:AZURE_CONFIG_DIR = $configDir
    # az looks for Bicep under its config folder, so reuse the copy installed on the image.
    $imageBicep = 'C:\Users\LabUser\.azure\bin\bicep.exe'
    if (Test-Path -LiteralPath $imageBicep) {
        New-Item -ItemType Directory -Force -Path (Join-Path $configDir 'bin') | Out-Null
        Copy-Item -LiteralPath $imageBicep -Destination (Join-Path $configDir 'bin')
    }
    Invoke-Az login --service-principal --username $clientId --password $clientSecret --tenant $tenantId --only-show-errors --output none | Out-Null
    Invoke-Az account set --subscription $subscriptionId | Out-Null

    Write-Status "Result: RUNNING`r`nDeploying Foundry into $resourceGroup. This takes a few minutes."
    Invoke-Az deployment group create --resource-group $resourceGroup --name lab661-foundry `
        --template-file (Join-Path $repoRoot 'infra\main.bicep') --only-show-errors --output none | Out-Null

    $outputs = (Invoke-Az deployment group show --resource-group $resourceGroup --name lab661-foundry `
        --query properties.outputs --output json | Out-String) | ConvertFrom-Json
    $endpoint = $outputs.openAiEndpoint.value.TrimEnd('/')
    $foundryName = $outputs.foundryName.value
    $connectionString = (Invoke-Az resource show --resource-group $resourceGroup --name $outputs.appInsightsName.value `
        --resource-type Microsoft.Insights/components --api-version 2020-02-02 `
        --query properties.ConnectionString --output tsv | Out-String).Trim()

    # Same keys as infra/setup.sh writes, but offline so the core labs keep their recorded output.
    $lines = foreach ($line in [IO.File]::ReadAllLines((Join-Path $repoRoot '.env.example'))) {
        switch -Regex ($line) {
            '^DEVBOT_MODE=' { 'DEVBOT_MODE=offline'; break }
            '^AZURE_API_BASE=' { "AZURE_API_BASE=$endpoint"; break }
            '^(DEVBOT_MODEL|ASSERT_MODEL)=' { "$($Matches[1])=azure/gpt-5.4-mini"; break }
            '^ASSERT_AZURE_USE_AAD=' { 'ASSERT_AZURE_USE_AAD=1'; break }
            '^APPLICATIONINSIGHTS_CONNECTION_STRING=' { "APPLICATIONINSIGHTS_CONNECTION_STRING='$connectionString'"; break }
            default { $line }
        }
    }
    [IO.File]::WriteAllText((Join-Path $repoRoot '.env'), (($lines -join "`n") + "`n"), $utf8)

    Write-Status "Result: READY`r`nResource group: $resourceGroup`r`nFoundry resource: $foundryName`r`nEndpoint: $endpoint`r`n.env written in offline mode. More 0 switches it to live."
}
catch {
    $message = ($_.Exception.Message -replace '[\r\n]+', ' ')
    if ($clientSecret) { $message = $message.Replace($clientSecret, '[redacted]') }
    Write-Status "Result: FAILED`r`n$message`r`nThe core labs still work. Ask a proctor before starting More 0."
    throw
}
finally {
    $env:AZURE_CONFIG_DIR = $previousConfigDir
    Remove-Item -LiteralPath $configDir -Recurse -Force -ErrorAction SilentlyContinue
}
