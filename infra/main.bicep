targetScope = 'resourceGroup'

param location string = 'westeurope'
param sqlServerName string = 'sql-radiusdemo-${uniqueString(resourceGroup().id)}'
param databaseName string = 'MtbBikeShop'
param identityName string = 'id-mtbbikeshop-azure-dev'
param sqlAdminObjectId string
param sqlAdminName string
@allowed([
  'User'
  'Group'
  'Application'
])
param sqlAdminPrincipalType string = 'User'
param oidcIssuer string
param kubernetesNamespace string = 'radiusdemo-entra'
param serviceAccountName string = 'mtbbikeshop'
param privateEndpointSubnetId string
param sqlPrivateDnsZoneId string

module appIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.6.0' = {
  name: 'app-identity'
  params: {
    name: identityName
    location: location
    enableTelemetry: false
    tags: {
      Environment: 'Development'
    }
    federatedIdentityCredentials: [
      {
        name: 'aks-mtbbikeshop'
        issuer: oidcIssuer
        subject: 'system:serviceaccount:${kubernetesNamespace}:${serviceAccountName}'
        audiences: [
          'api://AzureADTokenExchange'
        ]
      }
    ]
  }
}

module sql 'br/public:avm/res/sql/server:0.21.4' = {
  name: 'sql'
  params: {
    name: sqlServerName
    location: location
    enableTelemetry: false
    tags: {
      Environment: 'Development'
    }
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      login: sqlAdminName
      sid: sqlAdminObjectId
      principalType: sqlAdminPrincipalType
      tenantId: tenant().tenantId
    }
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Disabled'
    connectionPolicy: 'Proxy'
    lock: {
      kind: 'None'
    }
    databases: [
      {
        name: databaseName
        availabilityZone: -1
        sku: {
          name: 'Basic'
          tier: 'Basic'
        }
        maxSizeBytes: 2147483648
        zoneRedundant: false
        requestedBackupStorageRedundancy: 'Local'
      }
    ]
    privateEndpoints: [
      {
        name: 'pep-${sqlServerName}'
        subnetResourceId: privateEndpointSubnetId
        resourceGroupResourceId: resourceGroup().id
        service: 'sqlServer'
        tags: {
          Environment: 'Development'
        }
        privateDnsZoneGroup: {
          name: 'sql'
          privateDnsZoneGroupConfigs: [
            {
              name: 'sql'
              privateDnsZoneResourceId: sqlPrivateDnsZoneId
            }
          ]
        }
      }
    ]
  }
}

output sqlServerFqdn string = sql.outputs.fullyQualifiedDomainName
output sqlDatabaseName string = databaseName
output identityClientId string = appIdentity.outputs.clientId
output identityPrincipalId string = appIdentity.outputs.principalId
output identityName string = appIdentity.outputs.name
output serviceAccountName string = serviceAccountName
output kubernetesNamespace string = kubernetesNamespace
output connectionString string = 'Server=tcp:${sql.outputs.fullyQualifiedDomainName},1433;Database=${databaseName};Authentication=Active Directory Workload Identity;User Id=${appIdentity.outputs.clientId};Encrypt=True;TrustServerCertificate=False;'
