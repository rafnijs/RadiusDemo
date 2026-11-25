<#
.SYNOPSIS
  Step-by-step presenter script: deploy MTB Bikeshop with Radius to Docker Desktop (local)
  and to AKS with Azure SQL (Azure).

.DESCRIPTION
  Each step prints what it demonstrates and the command it runs, then waits:
    [Enter] run   [S] skip   [Q] quit
  A failing step offers [R] retry, [S] skip or [Q] quit.

  Local: SQL Server runs as a container in Docker Desktop Kubernetes (local-sqlserver recipe).
  Azure: Azure SQL with Entra-only auth; the app signs in with AKS workload identity (entra-container recipe).

.EXAMPLE
  .\.radius\demo.ps1                     # local, then Azure
  .\.radius\demo.ps1 -Target Local
  .\.radius\demo.ps1 -Target Azure -SkipInfra
  .\.radius\demo.ps1 -Target Local -NoPause   # rehearsal: run every step without prompts
#>
[CmdletBinding()]
param(
  [ValidateSet('Local', 'Azure', 'Both')]
  [string]$Target = 'Both',
  # Keep the existing app instead of deleting it first.
  [switch]$KeepApp,
  # Skip the Azure Bicep provisioning and database grant steps.
  [switch]$SkipInfra,
  [switch]$NoPause,

  [string]$LocalKubeContext = 'docker-desktop',
  [string]$LocalWorkspace = 'default',
  [string]$LocalGroup = 'default',
  [string]$LocalEnvironment = 'mtbbikeshop-local',
  [string]$LocalNamespace = 'radiusdemo-local',
  [int]$LocalAppPort = 8090,
  [int]$RecipeRegistryPort = 5000,

  [string]$AzureKubeContext = 'aks-aks-lz-a-weu-01',
  [string]$AzureWorkspace = 'azure-dev',
  [string]$AzureGroup = 'azure-dev',
  [string]$AzureEnvironment = 'mtbbikeshop-entra',
  [string]$AzureNamespace = 'radiusdemo-entra',
  [string]$SubscriptionId = 'd72f21eb-45ad-42d8-b94b-bc859be8a4aa',
  [string]$ResourceGroup = 'rg-radiusdemo-azure-dev',
  [string]$AzureDeploymentName = 'mtbbikeshop-entra',
  [string]$AcrName = 'acrakslzaweua4aa01',
  [string]$AzureRecipeTag = 'v1',
  [int]$AzurePortForwardPort = 8091
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

$script:portForward = $null
$script:stepNumber = 0

function Write-Section([string]$Title) {
  Write-Host ''
  Write-Host ('=' * 78) -ForegroundColor DarkCyan
  Write-Host "  $Title" -ForegroundColor Cyan
  Write-Host ('=' * 78) -ForegroundColor DarkCyan
}

function Invoke-Step {
  param(
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$Explain,
    [Parameter(Mandatory)][scriptblock]$Action
  )
  $script:stepNumber++
  Write-Host ''
  Write-Host "[$script:stepNumber] $Title" -ForegroundColor Yellow
  Write-Host "    $Explain" -ForegroundColor Gray
  # Show the command as written (variables unexpanded) so secrets are never printed.
  $Action.ToString().Trim() -split "`n" | ForEach-Object { Write-Host "    > $($_.Trim())" -ForegroundColor DarkGreen }

  if (-not $NoPause) {
    $answer = Read-Host '    [Enter] run  [S] skip  [Q] quit'
    if ($answer -match '^[sS]') { Write-Host '    skipped' -ForegroundColor DarkGray; return }
    if ($answer -match '^[qQ]') { throw [OperationCanceledException]::new('Demo stopped by presenter.') }
  }

  while ($true) {
    try {
      $global:LASTEXITCODE = 0
      & $Action
      if ($LASTEXITCODE -ne 0) { throw "exit code $LASTEXITCODE" }
      Write-Host '    done' -ForegroundColor Green
      return
    } catch [OperationCanceledException] {
      throw
    } catch {
      Write-Host "    FAILED: $_" -ForegroundColor Red
      if ($NoPause) { throw }
      $answer = Read-Host '    [R] retry  [S] skip  [Q] quit'
      if ($answer -match '^[sS]') { return }
      if ($answer -match '^[qQ]') { throw [OperationCanceledException]::new('Demo stopped by presenter.') }
    }
  }
}

# Native commands don't throw on failure; wrap the ones a step runs in sequence.
function Exec([scriptblock]$Command) {
  Repair-KubeServerUrl $LocalKubeContext
  Repair-KubeServerUrl $AzureKubeContext
  & $Command
  if ($LASTEXITCODE -ne 0) { throw "Command failed (exit $LASTEXITCODE): $($Command.ToString().Trim())" }
}

# rad 0.61 reports "installation could not be found" when the kubeconfig server URL ends with '/'.
function Repair-KubeServerUrl([string]$KubeContext) {
  $server = kubectl config view --minify --context $KubeContext -o jsonpath='{.clusters[0].cluster.server}'
  if ($LASTEXITCODE -ne 0 -or -not $server.EndsWith('/')) { return }
  $cluster = kubectl config view --minify --context $KubeContext -o jsonpath='{.clusters[0].name}'
  kubectl config set-cluster $cluster --server $server.TrimEnd('/') | Out-Null
}

function Get-LocalSqlPassword {
  if ($env:MTB_SQL_PASSWORD) { return $env:MTB_SQL_PASSWORD }
  $encoded = kubectl --context $LocalKubeContext -n $LocalNamespace get secret shopdb-credentials --ignore-not-found -o json
  if ($LASTEXITCODE -ne 0) { throw 'Cannot read local SQL credentials from Kubernetes.' }
  if ($encoded) {
    $encoded = ($encoded | ConvertFrom-Json).data.MSSQL_SA_PASSWORD
    if (-not $encoded) { throw 'Secret shopdb-credentials is missing MSSQL_SA_PASSWORD.' }
  }
  if ($encoded) { return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded)) }
  $bytes = New-Object byte[] 20
  $generator = [Security.Cryptography.RandomNumberGenerator]::Create()
  try { $generator.GetBytes($bytes) } finally { $generator.Dispose() }
  $random = [Convert]::ToBase64String($bytes)
  # Prefix/suffix guarantee SQL Server's upper/lower/digit/symbol complexity rules.
  return "Mtb!${random}9a"
}

function Get-AzureOutputs {
  $json = az deployment group show --subscription $SubscriptionId --resource-group $ResourceGroup `
    --name $AzureDeploymentName --query properties.outputs --output json
  if ($LASTEXITCODE -ne 0) { throw "Cannot read outputs of Azure deployment '$AzureDeploymentName'." }
  return $json | ConvertFrom-Json
}

function Wait-HttpOk([string]$Url, [int]$TimeoutSeconds = 120) {
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    try {
      $response = Invoke-WebRequest $Url -UseBasicParsing -TimeoutSec 10
      if ($response.StatusCode -eq 200) { Write-Host "    $Url -> 200 OK"; return }
    } catch { }
    Start-Sleep -Seconds 3
  }
  throw "$Url did not respond with 200 within $TimeoutSeconds seconds."
}

function Invoke-LocalDemo {
  Write-Section 'LOCAL - Docker Desktop Kubernetes + SQL Server container'

  Invoke-Step 'Show the local Radius workspace' `
    'A workspace points the rad CLI at a Radius control plane; here Radius runs in Docker Desktop Kubernetes.' {
    Exec { rad workspace show -w $LocalWorkspace }
    Exec { kubectl --context $LocalKubeContext -n radius-system get pods }
  }

  if (-not $KeepApp) {
    Invoke-Step 'Clean slate: delete the local app' `
      'Deleting the Radius app also removes everything its recipes created (pods, services, SQL volume).' {
      Exec { rad app delete radius-demo --preview -w $LocalWorkspace -g $LocalGroup -y }
    }
  }

  Invoke-Step 'Start a local OCI registry for recipes' `
    'Recipes are Bicep modules pulled from an OCI registry; locally a registry:2 container serves them.' {
    $status = docker ps -a --filter 'name=^radius-recipe-registry$' --format '{{.Status}}'
    if (-not $status) {
      Exec { docker run -d --name radius-recipe-registry --restart unless-stopped -p "127.0.0.1:${RecipeRegistryPort}:5000" registry:2 }
    } elseif ($status -notmatch '^Up') {
      Exec { docker start radius-recipe-registry }
    }
    Exec { docker ps --filter 'name=^radius-recipe-registry$' }
  }

  Invoke-Step 'Publish the local recipes' `
    'local-sqlserver: SQL Server 2022 container + volume. local-container: Deployment + LoadBalancer on localhost.' {
    foreach ($recipe in 'local-sqlserver', 'local-container') {
      Exec { rad bicep publish --file ".radius/recipes/local/$recipe.bicep" --target "br:localhost:${RecipeRegistryPort}/radius-recipes/${recipe}:1.0" --plain-http }
    }
  }

  Invoke-Step 'Deploy the local environment and recipe pack' `
    'The environment decides HOW resource types are implemented: here sqlServerDatabases -> SQL container.' {
    Exec { rad group create $LocalGroup -w $LocalWorkspace }
    kubectl --context $LocalKubeContext get namespace $LocalNamespace 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Exec { kubectl --context $LocalKubeContext create namespace $LocalNamespace } }
    rad env show $LocalEnvironment --preview -w $LocalWorkspace -g $LocalGroup 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
      Exec { rad env create $LocalEnvironment --preview -w $LocalWorkspace -g $LocalGroup --kubernetes-namespace $LocalNamespace }
    }
    Exec {
      rad deploy .radius/local-environment.bicep -w $LocalWorkspace -g $LocalGroup -e $LocalEnvironment `
        -p "recipeRegistry=host.docker.internal:${RecipeRegistryPort}/radius-recipes" -p "kubernetesNamespace=$LocalNamespace"
    }
  }

  Invoke-Step 'Deploy the application' `
    'app.local.bicep declares the app, a SQL database and the container; the recipes provision them.' {
    $sqlPassword = Get-LocalSqlPassword
    Exec { rad deploy .radius/app.local.bicep -w $LocalWorkspace -g $LocalGroup -e $LocalEnvironment -p "sqlPassword=$sqlPassword" }
  }

  Invoke-Step 'Show what Radius created' `
    'The app graph maps each Radius resource to the Kubernetes objects its recipe created.' {
    Exec { kubectl --context $LocalKubeContext -n $LocalNamespace rollout status deploy/shopdb --timeout=180s }
    Exec { kubectl --context $LocalKubeContext -n $LocalNamespace rollout status deploy/radius-demo --timeout=180s }
    Exec { rad app graph radius-demo --preview -w $LocalWorkspace -g $LocalGroup }
    Exec { kubectl --context $LocalKubeContext -n $LocalNamespace get deploy,svc,pvc }
  }

  Invoke-Step 'Open the shop' `
    "Docker Desktop publishes the LoadBalancer Service on http://localhost:$LocalAppPort." {
    Wait-HttpOk "http://localhost:$LocalAppPort/"
    Start-Process "http://localhost:$LocalAppPort/"
  }
}

function Invoke-AzureDemo {
  Write-Section 'AZURE - AKS + Azure SQL (Entra-only, workload identity)'

  Invoke-Step 'Show the Azure Radius workspace and Azure sign-in' `
    'Same rad CLI, different workspace: this one targets Radius on the AKS cluster.' {
    Exec { rad workspace show -w $AzureWorkspace }
    Exec { az account show --query '{subscription:name, user:user.name}' -o table }
  }

  if (-not $KeepApp) {
    Invoke-Step 'Clean slate: delete the Azure app' `
      'Removes the app, its Deployment, Service and ServiceAccount. Azure SQL and the identity are kept.' {
      Exec { rad app delete radius-demo --preview -w $AzureWorkspace -g $AzureGroup -y }
    }
  }

  if (-not $SkipInfra) {
    Invoke-Step 'Provision Azure SQL, private endpoint and app identity (Bicep)' `
      'Platform infra outside Radius: Entra-only SQL, private endpoint, managed identity federated to AKS. Takes a few minutes.' {
      Exec {
        az deployment group create --subscription $SubscriptionId --resource-group $ResourceGroup `
          --name $AzureDeploymentName --template-file infra/main.bicep --parameters infra/azure-dev.bicepparam `
          --query '{state:properties.provisioningState}' -o table
      }
    }

    Invoke-Step 'Grant the app identity access to the database' `
      'Runs a short Job in AKS (SQL is private) that creates the contained Entra user for the managed identity.' {
      Exec { & ./infra/Grant-DatabaseAccessFromAks.ps1 -SubscriptionId $SubscriptionId -ResourceGroup $ResourceGroup -DeploymentName $AzureDeploymentName -KubeContext $AzureKubeContext }
    }
  }

  Invoke-Step 'Publish the Azure container recipe to ACR' `
    'entra-container adds a ServiceAccount bound to the managed identity (workload identity) to the Deployment.' {
    # ACR is private: publishing needs VPN. Without it, Radius keeps using the already-published tag.
    $acrIps = try { [Net.Dns]::GetHostAddresses("$AcrName.azurecr.io").IPAddressToString } catch { @() }
    if (-not ($acrIps | Where-Object { $_ -match '^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)' })) {
      Write-Host "    ACR '$AcrName' has no private IP from here (VPN required). Using the published recipe tag '$AzureRecipeTag'." -ForegroundColor DarkYellow
      return
    }
    Exec { $null | az acr login --name $AcrName --subscription $SubscriptionId }
    Exec { rad bicep publish --file .radius/recipes/azure/entra-container.bicep --target "br:$AcrName.azurecr.io/radius/mtbbikeshop-entra:$AzureRecipeTag" }
  }

  Invoke-Step 'Deploy the Azure environment and recipe pack' `
    'Same resource type (Radius.Compute/containers), different recipe: this one adds Entra workload identity.' {
    $outputs = Get-AzureOutputs
    kubectl --context $AzureKubeContext get namespace $AzureNamespace 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Exec { kubectl --context $AzureKubeContext create namespace $AzureNamespace } }
    Exec {
      rad deploy .radius/entra-environment.bicep -w $AzureWorkspace -g $AzureGroup `
        -p "identityClientId=$($outputs.identityClientId.value)" `
        -p "workloadRecipeSource=$AcrName.azurecr.io/radius/mtbbikeshop-entra:$AzureRecipeTag" `
        -p "registrySettingsId=/planes/radius/local/resourceGroups/$AzureGroup/providers/Radius.Core/bicepSettings/$AzureEnvironment"
    }
  }

  Invoke-Step 'Deploy the application' `
    'app.bicep: the connection string carries no password; the pod signs in to Azure SQL with its federated identity.' {
    $outputs = Get-AzureOutputs
    Exec {
      rad deploy .radius/app.bicep -w $AzureWorkspace -g $AzureGroup `
        -p "environment=/planes/radius/local/resourceGroups/$AzureGroup/providers/Radius.Core/environments/$AzureEnvironment" `
        -p "sqlServerFqdn=$($outputs.sqlServerFqdn.value)" `
        -p "databaseName=$($outputs.sqlDatabaseName.value)" `
        -p "identityClientId=$($outputs.identityClientId.value)"
    }
  }

  Invoke-Step 'Show what Radius created' `
    'The pod runs as the mtbbikeshop ServiceAccount with azure.workload.identity/use=true.' {
    Exec { kubectl --context $AzureKubeContext -n $AzureNamespace rollout status deploy/radius-demo --timeout=180s }
    Exec { rad app graph radius-demo --preview -w $AzureWorkspace -g $AzureGroup }
    Exec { kubectl --context $AzureKubeContext -n $AzureNamespace get pods -l radapp.io/resource=radius-demo -L azure.workload.identity/use -o wide }
  }

  Invoke-Step 'Open the shop (port-forward, no public ingress)' `
    "SQL and the app are private; a port-forward exposes the app on http://localhost:$AzurePortForwardPort." {
    if ($script:portForward -and -not $script:portForward.HasExited) { Stop-Process -Id $script:portForward.Id }
    $script:portForward = Start-Process kubectl -PassThru -WindowStyle Hidden -ArgumentList @(
      '--context', $AzureKubeContext, '-n', $AzureNamespace, 'port-forward',
      'service/radius-demo-radiusdemo', "${AzurePortForwardPort}:8080")
    Wait-HttpOk "http://localhost:$AzurePortForwardPort/"
    Start-Process "http://localhost:$AzurePortForwardPort/"
  }
}

try {
  if ($Target -in 'Local', 'Both') { Invoke-LocalDemo }
  if ($Target -in 'Azure', 'Both') { Invoke-AzureDemo }
  Write-Section 'Demo complete'
  if ($Target -in 'Local', 'Both') { Write-Host "  Local: http://localhost:$LocalAppPort" }
  if ($Target -in 'Azure', 'Both') { Write-Host "  Azure: http://localhost:$AzurePortForwardPort (port-forward)" }
  if ($script:portForward -and -not $NoPause) {
    Read-Host '  Press Enter to stop the Azure port-forward and exit' | Out-Null
  }
} catch [OperationCanceledException] {
  Write-Host $_.Exception.Message -ForegroundColor Yellow
} finally {
  if ($script:portForward -and -not $script:portForward.HasExited) { Stop-Process -Id $script:portForward.Id }
}
