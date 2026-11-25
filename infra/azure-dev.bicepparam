using './main.bicep'

param sqlAdminObjectId = '919469ac-5490-46cf-94df-ee23ce063d1f'
param sqlAdminName = 'Raf Nijs'
param oidcIssuer = 'https://westeurope.oic.prod-aks.azure.com/26192361-e292-499b-87f4-396373fd598e/4f76056f-31e2-406e-b4a7-7638769df07f/'
param privateEndpointSubnetId = '/subscriptions/d72f21eb-45ad-42d8-b94b-bc859be8a4aa/resourceGroups/rg-aks-corp-a-weu-01/providers/Microsoft.Network/virtualNetworks/vnet-aks-corp-a-weu-01/subnets/privateEndpoint'
param sqlPrivateDnsZoneId = '/subscriptions/66fef7c5-5480-40b5-8b2f-37fba70c5b40/resourceGroups/rg-infr-privatelinkzones-p-weu-01/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net'
