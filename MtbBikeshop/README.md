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
