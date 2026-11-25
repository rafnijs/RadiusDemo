<#
.SYNOPSIS
  Deploys the MTB Bikeshop to Docker Desktop Kubernetes with Radius, using local recipes
  for the container and a SQL Server instance.

.DESCRIPTION
  1. Starts a local OCI registry (registry:2) for the recipes.
  2. Publishes recipes/local/local-sqlserver.bicep and recipes/local/local-container.bicep to it.
  3. Creates the Radius resource group, namespace and environment (first run only) and
     deploys local-environment.bicep, which registers the recipe pack.
  4. Deploys app.local.bicep. The app is reachable at http://localhost:8090.

  The SQL SA password is taken from $env:MTB_SQL_PASSWORD, otherwise reused from the existing
  deployment (the data volume keeps the original password), otherwise generated.
#>
[CmdletBinding()]
param(
  [string]$KubeContext = 'docker-desktop',
  [string]$Workspace = 'default',
  [string]$Group = 'default',
  [string]$Environment = 'mtbbikeshop-local',
  [string]$Namespace = 'radiusdemo-local',
  [string]$RecipeVersion = '1.0',
  [int]$RegistryPort = 5000,
  [string]$RegistryContainer = 'radius-recipe-registry'
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

function Invoke-Native {
  param([Parameter(Mandatory)][scriptblock]$Command)
  & $Command
  if ($LASTEXITCODE -ne 0) { throw "Command failed (exit $LASTEXITCODE): $Command" }
}

Write-Host '==> Checking Radius on' $KubeContext
Invoke-Native { kubectl --context $KubeContext -n radius-system rollout status deploy/ucp --timeout=60s }

Write-Host '==> Starting local recipe registry'
$existing = docker ps -a --filter "name=^$RegistryContainer$" --format '{{.Status}}'
if (-not $existing) {
  Invoke-Native { docker run -d --name $RegistryContainer --restart unless-stopped -p "127.0.0.1:${RegistryPort}:5000" registry:2 }
} elseif ($existing -notmatch '^Up') {
  Invoke-Native { docker start $RegistryContainer }
}

Write-Host '==> Publishing recipes'
foreach ($recipe in 'local-sqlserver', 'local-container') {
  Invoke-Native { rad bicep publish --file "recipes/local/$recipe.bicep" --target "br:localhost:${RegistryPort}/radius-recipes/${recipe}:$RecipeVersion" --plain-http }
}

Write-Host '==> Ensuring resource group, namespace and environment'
Invoke-Native { rad group create $Group -w $Workspace }
kubectl --context $KubeContext get namespace $Namespace 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { Invoke-Native { kubectl --context $KubeContext create namespace $Namespace } }
rad env show $Environment -w $Workspace -g $Group --preview 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
  Invoke-Native { rad env create $Environment --preview -w $Workspace -g $Group --kubernetes-namespace $Namespace }
}
Invoke-Native {
  rad deploy local-environment.bicep -w $Workspace -g $Group -e $Environment `
    -p "recipeRegistry=host.docker.internal:${RegistryPort}/radius-recipes" `
    -p "recipeVersion=$RecipeVersion" `
    -p "kubernetesNamespace=$Namespace"
}

Write-Host '==> Resolving SQL SA password'
$sqlPassword = $env:MTB_SQL_PASSWORD
if (-not $sqlPassword) {
  $encoded = kubectl --context $KubeContext -n $Namespace get secret shopdb-credentials --ignore-not-found -o json
  if ($LASTEXITCODE -ne 0) { throw 'Cannot read local SQL credentials from Kubernetes.' }
  if ($encoded) {
    $encoded = ($encoded | ConvertFrom-Json).data.MSSQL_SA_PASSWORD
    if (-not $encoded) { throw 'Secret shopdb-credentials is missing MSSQL_SA_PASSWORD.' }
    $sqlPassword = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
  }
}
if (-not $sqlPassword) {
  $bytes = New-Object byte[] 20
  $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
  try { $generator.GetBytes($bytes) } finally { $generator.Dispose() }
  $random = [Convert]::ToBase64String($bytes)
  # Prefix/suffix guarantee SQL Server's upper/lower/digit/symbol complexity rules.
  $sqlPassword = "Mtb!${random}9a"
}

Write-Host '==> Deploying application'
Invoke-Native { rad deploy app.local.bicep -w $Workspace -g $Group -e $Environment -p "sqlPassword=$sqlPassword" }

Write-Host '==> Waiting for pods'
Invoke-Native { kubectl --context $KubeContext -n $Namespace rollout status deploy/shopdb --timeout=180s }
Invoke-Native { kubectl --context $KubeContext -n $Namespace rollout status deploy/radius-demo --timeout=180s }
Write-Host 'MTB Bikeshop is running at http://localhost:8090'
