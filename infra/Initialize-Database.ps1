[CmdletBinding()]
param(
    [string] $SubscriptionId = 'd72f21eb-45ad-42d8-b94b-bc859be8a4aa',
    [string] $ResourceGroup = 'rg-radiusdemo-azure-dev',
    [string] $DeploymentName = 'mtbbikeshop-entra'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Get-Command Invoke-Sqlcmd -ErrorAction SilentlyContinue)) {
    throw 'Invoke-Sqlcmd is required. Install the SqlServer PowerShell module and rerun this script.'
}

$outputJson = az deployment group show --subscription $SubscriptionId `
    --resource-group $ResourceGroup --name $DeploymentName `
    --query properties.outputs --output json
if ($LASTEXITCODE -ne 0) {
    throw "Cannot read outputs from deployment '$DeploymentName'."
}
$outputs = $outputJson | ConvertFrom-Json
$clientId = [guid]::Parse($outputs.identityClientId.value)
$server = $outputs.sqlServerFqdn.value
$database = $outputs.sqlDatabaseName.value

$addresses = [System.Net.Dns]::GetHostAddresses($server)
if ($addresses.Count -eq 0) {
    throw "SQL hostname '$server' did not resolve. Check VPN and private DNS."
}
Write-Host "SQL hostname resolves to: $($addresses.IPAddressToString -join ', ')"

$tokenJson = az account get-access-token --subscription $SubscriptionId `
    --resource https://database.windows.net/ --output json
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to obtain an Entra SQL token. Sign in as the configured SQL administrator.'
}
$accessToken = ($tokenJson | ConvertFrom-Json).accessToken

Invoke-Sqlcmd -ServerInstance "tcp:$server,1433" -Database $database `
    -AccessToken $accessToken -InputFile (Join-Path $PSScriptRoot 'grant-app-access.sql') `
    -Variable "IdentityClientId=$clientId" -AbortOnError -ErrorAction Stop
Write-Host "Granted database access to app identity client ID $clientId in '$database'."
