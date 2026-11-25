# Passwordless Radius demo

## Scope and status

This is a hand-authored demo, not a generated Radius application model.
Azure Bicep provisions Azure SQL, its private endpoint/DNS zone group and a
dedicated application managed identity. Radius deploys the application through
an app-specific Kubernetes recipe into the existing AKS cluster.

SQL is deliberately **not** a Radius-managed database node. The installed
`Radius.Data/sqlServerDatabases` schema requires a username/password and is not
suitable for this Entra-only setup. The previous generated origin record was
removed rather than claiming this hand-authored model was generator-validated.

Azure infrastructure is provisioned. An AKS test resolved SQL to its private
endpoint and reached TCP 1433. The administrator grant Job created the database
user using the managed identity's client ID and verified its SID and database
roles. The app pod now starts successfully through workload identity, connects to
SQL, and serves the seeded catalog over a local port-forward. A checkout and
order-persistence-after-restart have not yet been tested.

## Architecture

- Subscription: `d72f21eb-45ad-42d8-b94b-bc859be8a4aa`.
- Resource group: `rg-radiusdemo-azure-dev`, West Europe.
- SQL: Basic/2 GB, Entra-only, TLS validation enabled, public network access
  disabled, Proxy connection policy (TCP 1433).
- Entra administrator: Raf Nijs, as recorded in
  [azure-dev.bicepparam](azure-dev.bicepparam). Prefer an approved administrator
  group for a long-lived environment.
- Identity: `id-mtbbikeshop-azure-dev`, federated only to
  `system:serviceaccount:radiusdemo-entra:mtbbikeshop` on this AKS issuer.
- Private endpoint uses the existing `privateEndpoint` subnet in
  `vnet-aks-corp-a-weu-01`. The zone group links to the existing central
  `privatelink.database.windows.net` zone. No VNet, subnet, DNS forwarder or
  policy assignment is changed.
- A new Radius environment and recipe pack, both named `mtbbikeshop-entra`,
  isolate this recipe from the existing `azure-dev` environment. They use the
  existing Radius group `azure-dev` and a dedicated Kubernetes namespace
  `radiusdemo-entra`. Radius requires a unique namespace per environment.
- The existing private ACR image is used; BuildKit, GitHub credentials and policy
  exemptions are not needed. A new image is required after application changes.

The custom [container recipe](../.radius/recipes/azure/entra-container.bicep) is
intentionally limited to this one web container and its plain environment values.
It is not a general replacement for the standard containers recipe. It creates a
service account, one Deployment and a ClusterIP Service. Workload identity is
bound in the recipe, so redeploys do not depend on manual pod patches.

## Prerequisites

- Azure permissions to deploy SQL and managed identity resources to the demo
  resource group, join the private-endpoint subnet, and attach the central DNS
  zone in its separate subscription. Reading those resources is not proof of
  write permissions.
- AKS workload identity and the OIDC issuer must remain enabled.
- The cluster needs working private DNS and TCP 1433 access to SQL's private IP.
  Workstation administration additionally needs VPN routing and private DNS;
  otherwise use the AKS grant Job below.
- The Radius recipe registry must be reachable by both the publishing workstation
  and Radius, and Radius must be configured to pull private Bicep recipes.
- `az`, the Radius CLI, `kubectl` and the `SqlServer` PowerShell module
  (`Invoke-Sqlcmd`) are needed for the commands below.

## Provision and grant access

From the repository root, review the parameter file, then validate before creating
resources:

```powershell
az deployment group validate `
  --subscription d72f21eb-45ad-42d8-b94b-bc859be8a4aa `
  --resource-group rg-radiusdemo-azure-dev `
  --template-file .\infra\main.bicep `
  --parameters .\infra\azure-dev.bicepparam

az deployment group create `
  --subscription d72f21eb-45ad-42d8-b94b-bc859be8a4aa `
  --resource-group rg-radiusdemo-azure-dev `
  --name mtbbikeshop-entra `
  --template-file .\infra\main.bicep `
  --parameters .\infra\azure-dev.bicepparam
```

The zone group creates the SQL DNS record. Before proceeding, check that the SQL
FQDN resolves to the new private endpoint from both AKS and the VPN workstation.
Do not create a public SQL firewall exception if DNS or routing fails.

Sign in to Azure CLI as the configured Entra SQL administrator and run:

```powershell
.\infra\Initialize-Database.ps1
```

If the workstation cannot reach SQL, run the grant from AKS instead:

```powershell
.\infra\Grant-DatabaseAccessFromAks.ps1
```

The AKS helper defaults to the existing `radiusdemo` namespace for administration
and uses an explicit kube context. It mounts an administrator token in a temporary
Secret, runs a non-root SDK Job, and removes the Secret and ConfigMap in `finally`.
It temporarily writes the token to the workstation's temp directory and deletes
that file in `finally`. The Job requires outbound NuGet access. The workstation
helper uses the token without saving it. Neither helper prints the token.

The SQL script creates a contained user using the app identity's **client ID**
as its SID, as required for service principals and managed identities in Azure
SQL Database. This uses the documented no-validation form, so no Microsoft
Graph lookup or Directory Readers grant is needed. It grants
`db_datareader`, `db_datawriter`, and `db_ddladmin`, not server administration or
`db_owner`. DDL access is needed because the app calls `EnsureCreatedAsync` on
startup; move schema creation to a migration job before removing this role.

## Publish the recipe and deploy through Radius

Publish the recipe to a registry you can push to. For example, when the workstation
has VPN connectivity and the required ACR permissions:

```powershell
az acr login --name acrakslzaweua4aa01
rad bicep publish --file .\.radius\recipes\azure\entra-container.bicep `
  --target br:acrakslzaweua4aa01.azurecr.io/radius/mtbbikeshop-entra:v1
```

Configure Radius's private Bicep registry authentication separately. AKS
`AcrPull` for application images does **not** automatically authenticate Radius's
Bicep recipe downloader. This installed Radius version requires tagged recipe
references; its downloader rejects digest references despite the publisher's
suggestion. It supports BasicAuth but not AzureWI for recipe registry access.

The platform exemption for `Enforce-GR-ContReg0` is now present at the Corp
scope. The `mtbbikeshop-recipe-pull` token is enabled and its stored credential
was verified against ACR. Radius's settings use the corresponding secret from
[registry-auth.bicep](../.radius/registry-auth.bicep). The credential expires
after 30 days. [Configure-RecipeRegistry.ps1](Configure-RecipeRegistry.ps1)
rotates and deploys a replacement credential; it uses a user-only ACL on its
temporary parameter file and deletes it in `finally`. Do not put credentials in
the model or recipe pack, or make the registry/source public.

Read the Azure deployment outputs, deploy the isolated Radius environment, then
the app:

```powershell
$o = az deployment group show `
  --subscription d72f21eb-45ad-42d8-b94b-bc859be8a4aa `
  --resource-group rg-radiusdemo-azure-dev --name mtbbikeshop-entra `
  --query properties.outputs --output json | ConvertFrom-Json

# Create namespace radiusdemo-entra first if it does not exist.
rad deploy .\.radius\entra-environment.bicep --workspace azure-dev `
  -p identityClientId=$($o.identityClientId.value) `
  -p workloadRecipeSource=acrakslzaweua4aa01.azurecr.io/radius/mtbbikeshop-entra:v1 `
  -p registrySettingsId=/planes/radius/local/resourceGroups/azure-dev/providers/Radius.Core/bicepSettings/mtbbikeshop-entra

rad deploy .\.radius\app.bicep --workspace azure-dev `
  -p environment=/planes/radius/local/resourceGroups/azure-dev/providers/Radius.Core/environments/mtbbikeshop-entra `
  -p sqlServerFqdn=$($o.sqlServerFqdn.value) `
  -p databaseName=$($o.sqlDatabaseName.value) `
  -p identityClientId=$($o.identityClientId.value)
```

Keep the environment recipe identity, the app connection-string identity and the
Azure deployment outputs in sync. The service-account name and namespace in the
recipe must match the identity's federated subject exactly.

## Verify the actual demo

```powershell
kubectl rollout status deployment/radius-demo -n radiusdemo-entra --timeout=180s
kubectl get pods -n radiusdemo-entra -l radapp.io/resource=radius-demo
kubectl logs deployment/radius-demo -n radiusdemo-entra --tail=80
kubectl port-forward -n radiusdemo-entra service/radius-demo-radiusdemo 8080:8080
```

Open `http://localhost:8080`, verify the seeded bike catalog, add an item to the
cart and complete a test checkout. Restart the app pod and verify that the order
remains in SQL. Check that the pod uses the `mtbbikeshop` service account, has
`azure.workload.identity/use=true`, and has a projected federated token file.
Do not print the token or its contents.

No public ingress or public SQL access is created. Azure resources incur charges
until removed. Radius application deletion does not delete the separately
provisioned SQL database or identity; review and remove only the demo's explicit
resources afterwards, not the shared subnet, central zone, namespace or resource
group.
