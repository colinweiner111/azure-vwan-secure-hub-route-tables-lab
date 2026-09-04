using './main.bicep'

param resourceGroupName = readEnvironmentVariable('AZURE_RESOURCE_GROUP_NAME', 'vwan-route-tables-lab')
param region1 = readEnvironmentVariable('AZURE_LOCATION', 'westus3')
param region2 = readEnvironmentVariable('AZURE_LOCATION_2', 'westus3')
param adminUsername = readEnvironmentVariable('AZURE_VM_ADMIN_USERNAME', 'azureuser')
param adminPassword = readEnvironmentVariable('AZURE_VM_ADMIN_PASSWORD')
param vmSize = readEnvironmentVariable('AZURE_VM_SIZE', 'Standard_D2ls_v7')
param firewallSku = readEnvironmentVariable('AZURE_FIREWALL_SKU', 'Premium')
param vpnSharedKey = readEnvironmentVariable('AZURE_VPN_SHARED_KEY')
