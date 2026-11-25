extension radius

param environment string
param sqlServerFqdn string
param identityClientId string
param databaseName string = 'MtbBikeShop'
param image string = 'acrakslzaweua4aa01.azurecr.io/mtbbikeshop:manufacturer-photos-20261112-1547'

resource radiusDemoApp 'Radius.Core/applications@2025-08-01-preview' = {
  name: 'radius-demo'
  properties: {
    environment: environment
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
            value: 'Server=tcp:${sqlServerFqdn},1433;Database=${databaseName};Authentication=Active Directory Workload Identity;User Id=${identityClientId};Encrypt=True;TrustServerCertificate=False;'
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
