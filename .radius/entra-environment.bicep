extension radius

param identityClientId string
param workloadRecipeSource string
param registrySettingsId string = ''
param tenantId string = '26192361-e292-499b-87f4-396373fd598e'
param serviceAccountName string = 'mtbbikeshop'
param kubernetesNamespace string = 'radiusdemo-entra'

resource workloadRecipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'mtbbikeshop-entra'
  properties: {
    recipes: {
      'Radius.Security/secrets': {
        kind: 'bicep'
        source: 'ghcr.io/radius-project/kube-recipes/secrets:latest'
      }
      'Radius.Compute/containers': {
        kind: 'bicep'
        source: workloadRecipeSource
        parameters: {
          identityClientId: identityClientId
          tenantId: tenantId
          serviceAccountName: serviceAccountName
        }
      }
    }
  }
}

resource demoEnvironment 'Radius.Core/environments@2025-08-01-preview' = {
  name: 'mtbbikeshop-entra'
  properties: {
    bicepSettings: registrySettingsId
    providers: {
      kubernetes: {
        namespace: kubernetesNamespace
      }
    }
    recipePacks: [
      workloadRecipes.id
    ]
  }
}

output environmentId string = demoEnvironment.id
