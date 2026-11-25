extension radius

param environment string

@description('Password for the OCI registry the containerImages recipe pushes to.')
@secure()
param registryPassword string

@description('Username for the OCI registry the containerImages recipe pushes to.')
@secure()
param registryUsername string

@description('Administrator password for the SQL Server database.')
@secure()
param sqlPassword string

resource radiusDemoApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'radius-demo'
  properties: {
    environment: environment
  }
}

resource sqlServerDb 'Radius.Data/sqlServerDatabases@2025-08-01-preview' = {
  name: 'sqlserver'
  properties: {
    environment: environment
    application: radiusDemoApp.id
    codeReference: 'MtbBikeshop/Program.cs#L12'
    database: 'MtbBikeShop'
    password: sqlPassword
    username: 'myadmin'
  }
}

resource appSecrets 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'app-secrets'
  properties: {
    environment: environment
    application: radiusDemoApp.id
    codeReference: 'MtbBikeshop/Program.cs#L7'
    data: {
      password: {
        value: sqlPassword
      }
    }
  }
}

resource registryCreds 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'radius-ghcr-registry-creds'
  properties: {
    environment: environment
    application: radiusDemoApp.id
    codeReference: '.radius/app.bicep#L50'
    data: {
      password: {
        value: registryPassword
      }
      username: {
        value: registryUsername
      }
    }
  }
}

resource radiusDemoImage 'Radius.Compute/containerImages@2025-08-01-preview' = {
  name: 'radius-demo-image'
  properties: {
    environment: environment
    application: radiusDemoApp.id
    codeReference: 'MtbBikeshop/Dockerfile'
    tag: '6cd6d59'
    build: {
      platforms: [
        'linux/amd64'
      ]
      source: 'git::https://github.com/rafnijs/RadiusDemo.git//MtbBikeshop?ref=6cd6d594a5d209258fb17ea8dd9c06d1f6738fa7'
    }
  }
  dependsOn: [
    registryCreds
  ]
}

resource radiusDemoContainer 'Radius.Compute/containers@2025-08-01-preview' = {
  name: 'radius-demo'
  properties: {
    environment: environment
    application: radiusDemoApp.id
    codeReference: 'MtbBikeshop/Program.cs#L5'
    containers: {
      radiusDemo: {
        image: radiusDemoImage.properties.imageReference
        env: {
          ConnectionStrings__ShopDb: {
            value: 'Server=tcp:${sqlServerDb.properties.host},1433;Database=MtbBikeShop;User ID=myadmin;Password=\'$(SHOPDB_PASSWORD)\';Encrypt=True;TrustServerCertificate=False;'
          }
          SHOPDB_PASSWORD: {
            valueFrom: {
              secretKeyRef: {
                key: 'password'
                secretName: appSecrets.name
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
  }
}
