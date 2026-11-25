[CmdletBinding()]
param(
    [string] $SubscriptionId = 'd72f21eb-45ad-42d8-b94b-bc859be8a4aa',
    [string] $Registry = 'acrakslzaweua4aa01',
    [string] $TokenName = 'mtbbikeshop-recipe-pull',
    [string] $Workspace = 'azure-dev',
    [string] $EnvironmentId = '/planes/radius/local/resourceGroups/azure-dev/providers/Radius.Core/environments/mtbbikeshop-entra'
)

$ErrorActionPreference = 'Stop'
$path = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
try {
    $credentialJson = az acr token credential generate --registry $Registry `
        --subscription $SubscriptionId --name $TokenName --password1 `
        --expiration-in-days 30 --output json
    if ($LASTEXITCODE -ne 0) { throw 'ACR token credential generation failed.' }
    $credential = $credentialJson | ConvertFrom-Json
    Remove-Variable credentialJson

    [IO.File]::WriteAllText($path, '')
    $acl = Get-Acl $path
    $acl.SetAccessRuleProtection($true, $false)
    $acl.SetAccessRule([Security.AccessControl.FileSystemAccessRule]::new(
        [Security.Principal.WindowsIdentity]::GetCurrent().Name, 'FullControl', 'Allow'))
    Set-Acl $path $acl
    @{
        parameters = @{
            environment = @{ value = $EnvironmentId }
            registryHost = @{ value = "$Registry.azurecr.io" }
            registryUsername = @{ value = $TokenName }
            registryPassword = @{ value = $credential.passwords[0].value }
        }
    } | ConvertTo-Json -Depth 6 | Set-Content $path
    Remove-Variable credential
    rad deploy (Join-Path $PSScriptRoot '..\.radius\registry-auth.bicep') `
        --workspace $Workspace --parameters "@$path"
    if ($LASTEXITCODE -ne 0) { throw 'Radius registry credential deployment failed.' }
}
finally {
    Remove-Item $path -Force -ErrorAction SilentlyContinue
}
