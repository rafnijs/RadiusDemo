extension radius

param environment string

@secure()
@description('SA password for the local SQL Server. Must meet SQL Server complexity rules.')
param sqlPassword string

param databaseName string = 'MtbBikeShop'
param image string = 'mtbbikeshop:manufacturer-photos-20261102-1213'

resource radiusDemoApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'radius-demo'
  properties: {
    environment: environment
  }
}

resource shopDb 'Radius.Data/sqlServerDatabases@2025-08-01-preview' = {
  name: 'shopdb'
  properties: {
    environment: environment
    application: radiusDemoApp.id
    database: databaseName
    username: 'sa'
    password: sqlPassword
  }
}

resource shopDbConnection 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'shopdb-connection'
  properties: {
    environment: environment
    application: radiusDemoApp.id
    data: {
      connectionString: {
        value: 'Server=${shopDb.properties.host},${shopDb.properties.port};Database=${shopDb.properties.database};User Id=sa;Password=${sqlPassword};Encrypt=True;TrustServerCertificate=True;'
      }
    }
  }
}

resource radiusDemoContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'radius-demo'
  properties: {
    environment: environment
    application: radiusDemoApp.id
    codeReference: 'MtbBikeshop/Program.cs#L5'
    containers: {
      radiusDemo: {
        image: image
        env: {
          ConnectionStrings__ShopDb: {
            valueFrom: {
              secretKeyRef: {
                secretName: shopDbConnection.name
                key: 'connectionString'
              }
            }
          }
        }
        ports: {
          web: {
            containerPort: 8080
          }
        }
      }
    }
    connections: {
      shopdb: {
        source: shopDb.id
      }
    }
  }
}
