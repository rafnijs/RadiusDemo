# MtbBikeshop

The application uses SQL Server. Set the `ConnectionStrings__ShopDb` environment
variable to a SQL Server connection string before starting the app. At startup,
the app creates the database schema and seeds the bike catalog.

For example, with a reachable SQL Server:

```powershell
$env:ConnectionStrings__ShopDb = "Server=localhost,1433;Database=MtbBikeShop;User Id=<user>;Password=<password>;Encrypt=True;TrustServerCertificate=True;"
dotnet run
```

The Docker image listens on port `8080` and requires the same environment variable:

```powershell
docker run --rm -p 8080:8080 `
  -e "ConnectionStrings__ShopDb=$env:ConnectionStrings__ShopDb" `
  mtbbikeshop:latest
```

## Bike photos

The catalog and detail pages use official manufacturer images, mapped by the
full brand/model name in `Services/BikePhotos.cs`, not by category or rank.
The shared `_BikePhoto.cshtml` partial displays the pictured model/build,
known differences from the catalog, copyright credit and the official source.
Unconfirmed build/model years are explicitly labeled. It never substitutes a
different model.

The site owner confirmed permission to use these manufacturer photos. They
remain copyrighted by their respective owners; this repository grants no rights
to reuse them. Images load directly from manufacturer CDNs and require internet
access. No manufacturer photos are copied into the repository.

Trek Fuel EX and Orbea Occam LT currently link to their exact official product
pages without embedding an image: Trek's gallery and Orbea's layered configurator
did not expose a verified standalone photo. Unknown models also show an explicit
unavailable message. If a remote image fails, the page displays an error message
and retains the manufacturer link instead of showing an unrelated bicycle.

Existing databases need no schema changes or reseeding. Rebuild and redeploy the
app image to show changes in a container deployment.

## Run the app and SQL Server with Docker Desktop on Windows

The repository root contains a Compose setup that builds the app and runs it
with SQL Server 2022 Developer Edition. It requires Docker Desktop in
Linux-container mode. The app connects to SQL Server over the Compose network;
the database data persists in a named volume. On first startup, the app creates
the schema and seeds the bike catalog.

From the repository root in PowerShell:

```powershell
Copy-Item .\.env.example .\.env
notepad .\.env
```

Set `MSSQL_SA_PASSWORD` in `.env` to a strong local-only password (at least
8 characters, using at least three of uppercase, lowercase, digits, and symbols).
Avoid semicolons and dollar signs because the password is interpolated into the
SQL connection string and Compose configuration. The `.env` file is git-ignored;
never commit or share it.

Start the app and database:

```powershell
docker compose up --build -d
docker compose ps
docker compose logs -f app
```

Open `http://localhost:8081`. The compose file binds the app and SQL Server only
to the local machine. Database tools can connect to `localhost,14330` with login
`sa` and the password from `.env`. Change `APP_PORT` or `SQL_PORT` there if these
ports are already in use.

Stop the containers but keep database data:

```powershell
docker compose down
```

To delete the demo database volume as well (permanently deleting local demo data
and orders), run `docker compose down --volumes`.

This setup is for local development/demo use only. SQL Server Developer Edition
is not licensed for production, and the sample `sa` connection is not a
production security configuration.

## Deploy with Radius to Docker Desktop Kubernetes

Radius can deploy the same app to the Kubernetes cluster built into Docker
Desktop, with a recipe that provisions SQL Server in the cluster. Prerequisites:
Docker Desktop with Kubernetes enabled, the `rad` CLI, and Radius installed on
the `docker-desktop` context (`rad install kubernetes`) with a `default`
workspace pointing at it.

Build the local application image first (also required before running the local
presenter demo). The local Bicep definition defaults to this tag so rerunning the
demo does not restore the older GHCR image without photos:

```powershell
docker build -t mtbbikeshop:manufacturer-photos-20261102-1213 .\MtbBikeshop
```

```powershell
.\.radius\deploy-local.ps1
```

The app is then available at <http://localhost:8090>. The script:

1. starts a local recipe registry container (`radius-recipe-registry`,
   `127.0.0.1:5000`);
2. publishes the local recipes in `.radius/recipes/local` (the AKS/Entra
   recipe lives in `.radius/recipes/azure`):
   - `local-sqlserver.bicep` (`Radius.Data/sqlServerDatabases`): SQL Server
     2022 Developer edition with a persistent volume and a ClusterIP Service;
   - `local-container.bicep` (`Radius.Compute/containers`): a Deployment plus
     a `LoadBalancer` Service that Docker Desktop publishes on localhost;
3. deploys `.radius/local-environment.bicep` (environment and recipe pack
   `mtbbikeshop-local`, namespace `radiusdemo-local`);
4. deploys `.radius/app.local.bicep`, which declares the database and passes
   the connection string to the container through a `Radius.Security/secrets`
   resource.

The SQL `sa` password comes from `$env:MTB_SQL_PASSWORD`. If it isn't set, the
script reuses the password from the existing deployment or generates a new one.
Both local scripts support Windows PowerShell 5.1 and PowerShell 7. A missing
`shopdb-credentials` secret is expected on a fresh deployment; other Kubernetes
lookup errors stop the deployment rather than generating a replacement password.
Remove the deployment with `rad app delete radius-demo --preview -w default -g default`.

## Presenter demo: local and Azure step by step

[demo.ps1](../.radius/demo.ps1) walks through both deployments. Each step shows
what it demonstrates and the command, then waits for Enter (S skips, Q quits; a
failed step can be retried).

```powershell
.\.radius\demo.ps1                          # local, then Azure
.\.radius\demo.ps1 -Target Local
.\.radius\demo.ps1 -Target Azure -SkipInfra # skip Azure SQL/identity provisioning and grant
.\.radius\demo.ps1 -Target Local -NoPause   # rehearsal without prompts
```

By default it deletes the app first so the audience sees a fresh deployment
(`-KeepApp` disables this). The local shop opens at <http://localhost:8090>,
the Azure shop through a port-forward at <http://localhost:8091>. Publishing the
Azure recipe needs VPN because the ACR is private; without VPN that step keeps
the already-published `v1` recipe.

## Azure SQL with Microsoft Entra sign-in

The demo uses a dedicated AKS workload identity, not a SQL password or the Radius
control-plane identity. SqlClient 6.1.7 (included through EF Core) supports
`Authentication=Active Directory Workload Identity`. No application code change
or new NuGet dependency is needed.

The existing connection-string setting remains the same. In AKS its value is:

```text
Server=tcp:<server>.database.windows.net,1433;Database=MtbBikeShop;Authentication=Active Directory Workload Identity;User Id=<app-identity-client-id>;Encrypt=True;TrustServerCertificate=False;
```

The `User Id` is the identity's **client ID**, not its object/principal ID.
The AKS workload identity webhook must inject `AZURE_TENANT_ID`,
`AZURE_CLIENT_ID`, and `AZURE_FEDERATED_TOKEN_FILE` into the pod.
Do not use `Active Directory Managed Identity` on AKS: that targets a different
token acquisition mechanism.

See [the demo deployment guide](../infra/README.md) for private networking,
database grants, the app-specific Radius recipe, and verification.
