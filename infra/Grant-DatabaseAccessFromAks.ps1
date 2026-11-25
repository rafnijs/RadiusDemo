[CmdletBinding()]
param(
    [string] $SubscriptionId = 'd72f21eb-45ad-42d8-b94b-bc859be8a4aa',
    [string] $ResourceGroup = 'rg-radiusdemo-azure-dev',
    [string] $DeploymentName = 'mtbbikeshop-entra',
    [string] $Namespace = 'radiusdemo',
    [string] $KubeContext = 'aks-aks-lz-a-weu-01',
    [int] $TimeoutSeconds = 600
)

# Runs grant-app-access.sql from inside AKS, for when the SQL private endpoint
# is reachable from the cluster but not from this workstation.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$outputJson = az deployment group show --subscription $SubscriptionId `
    --resource-group $ResourceGroup --name $DeploymentName `
    --query properties.outputs --output json
if ($LASTEXITCODE -ne 0) { throw "Cannot read outputs from deployment '$DeploymentName'." }
$outputs = $outputJson | ConvertFrom-Json
$clientId = [guid]::Parse($outputs.identityClientId.value)
$server = $outputs.sqlServerFqdn.value
$database = $outputs.sqlDatabaseName.value

$name = 'mtbbikeshop-db-grant'
$kubectl = @('--context', $KubeContext, '-n', $Namespace)
$tokenFile = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())

try {
    $token = az account get-access-token --subscription $SubscriptionId `
        --resource https://database.windows.net/ --query accessToken --output tsv
    if ($LASTEXITCODE -ne 0 -or -not $token) {
        throw 'Unable to obtain an Entra SQL token. Sign in as the configured SQL administrator.'
    }
    [IO.File]::WriteAllText($tokenFile, $token)
    Remove-Variable token

    kubectl @kubectl delete job $name --ignore-not-found --wait=true | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Cannot remove the previous grant Job.' }
    kubectl @kubectl create secret generic "$name-token" "--from-file=accessToken=$tokenFile" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create the temporary SQL token Secret.' }
    $sqlFile = Join-Path $PSScriptRoot 'grant-app-access.sql'
    $runnerFile = Join-Path $PSScriptRoot 'grant-runner\grant.cs'
    kubectl @kubectl create configmap "$name-sql" `
        "--from-file=$sqlFile" "--from-file=$runnerFile" | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create the SQL grant ConfigMap.' }

    $job = @"
apiVersion: batch/v1
kind: Job
metadata:
  name: $name
  labels: {app.kubernetes.io/name: $name}
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 600
  template:
    metadata:
      labels: {app.kubernetes.io/name: $name}
    spec:
      restartPolicy: Never
      automountServiceAccountToken: false
      securityContext: {runAsNonRoot: true, runAsUser: 1654, runAsGroup: 1654}
      containers:
      - name: grant
        image: mcr.microsoft.com/dotnet/sdk:10.0
        command: ["sh", "-c", "mkdir -p /tmp/work && cp /sql/grant.cs /tmp/work/ && cd /tmp/work && dotnet run grant.cs"]
        env:
        - {name: HOME, value: /tmp}
        - {name: DOTNET_CLI_TELEMETRY_OPTOUT, value: "1"}
        - {name: DOTNET_NOLOGO, value: "1"}
        - {name: SQL_SERVER, value: "$server"}
        - {name: SQL_DATABASE, value: "$database"}
        - {name: IDENTITY_CLIENT_ID, value: "$clientId"}
        securityContext: {allowPrivilegeEscalation: false}
        resources:
          requests: {cpu: 50m, memory: 256Mi}
          limits: {cpu: "1", memory: 1536Mi}
        volumeMounts:
        - {name: work, mountPath: /tmp}
        - {name: sql, mountPath: /sql, readOnly: true}
        - {name: token, mountPath: /token, readOnly: true}
      volumes:
      - {name: work, emptyDir: {}}
      - name: sql
        configMap: {name: $name-sql}
      - name: token
        secret: {secretName: $name-token}
"@
    $job | kubectl @kubectl apply -f - | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Cannot create the SQL grant Job.' }

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    do {
        Start-Sleep -Seconds 5
        $status = kubectl @kubectl get "job/$name" -o jsonpath='{.status.succeeded}/{.status.failed}'
        if ($LASTEXITCODE -ne 0) { throw 'Cannot read the SQL grant Job status.' }
    } while ($status -notmatch '^1/|/[1-9]' -and (Get-Date) -lt $deadline)
    kubectl @kubectl logs "job/$name"
    if ($status -ne '1/') { throw "Grant job did not succeed (succeeded/failed: '$status'). Inspect it with: kubectl -n $Namespace describe job/$name" }
    Write-Host "Granted database access to app identity client ID $clientId in '$database'."
}
finally {
    Remove-Item $tokenFile -Force -ErrorAction SilentlyContinue
    kubectl @kubectl delete secret "$name-token" --ignore-not-found | Out-Null
    kubectl @kubectl delete configmap "$name-sql" --ignore-not-found | Out-Null
}
