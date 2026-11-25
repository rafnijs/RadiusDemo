extension radius

param environment string
param registryHost string = 'acrakslzaweua4aa01.azurecr.io'
param registryUsername string = 'mtbbikeshop-recipe-pull'
@secure()
param registryPassword string

resource registrySecret 'Radius.Security/secrets@2025-08-01-preview' = {
  name: 'mtbbikeshop-recipe-pull'
  properties: {
    environment: environment
    kind: 'basicAuthentication'
    data: {
      username: {
        value: registryUsername
      }
      password: {
        value: registryPassword
      }
    }
  }
}

resource registrySettings 'Radius.Core/bicepSettings@2025-08-01-preview' = {
  name: 'mtbbikeshop-entra'
  properties: {
    registryAuthentications: {
      '${registryHost}': {
        authenticationMethod: 'BasicAuth'
        basicAuthSecretId: registrySecret.id
      }
    }
  }
}

output settingsId string = registrySettings.id
