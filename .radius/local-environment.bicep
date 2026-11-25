extension radius

@description('OCI path prefix the local recipes were published to, as seen from inside the cluster.')
param recipeRegistry string = 'host.docker.internal:5000/radius-recipes'

@description('Recipe tag published by deploy-local.ps1.')
param recipeVersion string = '1.0'

param kubernetesNamespace string = 'radiusdemo-local'

resource localRecipes 'Radius.Core/recipePacks@2025-08-01-preview' = {
  name: 'mtbbikeshop-local'
  properties: {
    recipes: {
      'Radius.Security/secrets': {
        kind: 'bicep'
        source: 'ghcr.io/radius-project/kube-recipes/secrets:latest'
      }
      'Radius.Data/sqlServerDatabases': {
        kind: 'bicep'
        source: '${recipeRegistry}/local-sqlserver:${recipeVersion}'
        plainHttp: true
      }
      'Radius.Compute/containers': {
        kind: 'bicep'
        source: '${recipeRegistry}/local-container:${recipeVersion}'
        plainHttp: true
        parameters: {
          serviceType: 'LoadBalancer'
          servicePort: 8090
        }
      }
    }
  }
}

resource localEnvironment 'Radius.Core/environments@2025-08-01-preview' = {
  name: 'mtbbikeshop-local'
  properties: {
    providers: {
      kubernetes: {
        namespace: kubernetesNamespace
      }
    }
    recipePacks: [
      localRecipes.id
    ]
  }
}

output environmentId string = localEnvironment.id
