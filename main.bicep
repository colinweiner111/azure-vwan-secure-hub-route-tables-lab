targetScope = 'subscription'

@description('Primary region for deployment')
param region1 string = 'westus3'

@description('Region for Hub 2 resources')
param region2 string = 'westus3'

@description('Resource group name')
param resourceGroupName string = 'vwan-route-tables-lab'

@description('Virtual WAN name')
param vwanName string = 'vwan-demo'

@description('Hub 1 name')
param hub1Name string = 'hub1'

@description('Hub 2 name')
param hub2Name string = 'hub2'

@description('Admin username for VMs')
param adminUsername string = 'azureuser'

@description('Admin password for VMs')
@secure()
param adminPassword string

@description('Pre-shared key for the site-to-site VPN connections')
@secure()
param vpnSharedKey string

@description('VM size')
param vmSize string = 'Standard_D2ls_v7'

@description('Azure Firewall SKU')
@allowed(['Standard', 'Premium'])
param firewallSku string = 'Premium'

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: region1
}

// Network Infrastructure
module network 'modules/network.bicep' = {
  scope: rg
  name: 'network-deployment'
  params: {
    location1: region1
    location2: region2
    vwanName: vwanName
    hub1Name: hub1Name
    hub2Name: hub2Name
  }
}

// Virtual Machines
module vms 'modules/vms.bicep' = {
  scope: rg
  name: 'vms-deployment'
  params: {
    location1: region1
    location2: region2
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
    branchVnetId: network.outputs.branchVnetId
    spoke1Hub1Id: network.outputs.spoke1Hub1Id
    spoke2Hub1Id: network.outputs.spoke2Hub1Id
    spoke1Hub2Id: network.outputs.spoke1Hub2Id
    spoke2Hub2Id: network.outputs.spoke2Hub2Id
  }
}

// Azure Firewall
module firewall 'modules/firewall.bicep' = {
  scope: rg
  name: 'firewall-deployment'
  params: {
    location1: region1
    location2: region2
    hub1Name: hub1Name
    hub2Name: hub2Name
    hub1Id: network.outputs.hub1Id
    hub2Id: network.outputs.hub2Id
    firewallSku: firewallSku
  }
  dependsOn: [
    vpn
  ]
}

// Virtual hub route tables and spoke connections
module routing 'modules/routing.bicep' = {
  scope: rg
  name: 'routing-deployment'
  params: {
    hub1Name: hub1Name
    hub2Name: hub2Name
    hub1FirewallId: firewall.outputs.hub1FirewallId
    hub2FirewallId: firewall.outputs.hub2FirewallId
    hub1SpokePrefixes: network.outputs.hub1SpokePrefixes
    hub2SpokePrefixes: network.outputs.hub2SpokePrefixes
    spoke1Hub1Id: network.outputs.spoke1Hub1Id
    spoke2Hub1Id: network.outputs.spoke2Hub1Id
    spoke1Hub2Id: network.outputs.spoke1Hub2Id
    spoke2Hub2Id: network.outputs.spoke2Hub2Id
  }
}

// VPN Infrastructure
module vpn 'modules/vpn.bicep' = {
  scope: rg
  name: 'vpn-deployment'
  params: {
    location1: region1
    location2: region2
    hub1Name: hub1Name
    hub2Name: hub2Name
    vwanName: vwanName
    branchVnetId: network.outputs.branchVnetId
    hub1Id: network.outputs.hub1Id
    hub2Id: network.outputs.hub2Id
    hub1DefaultRouteTableId: '${network.outputs.hub1Id}/hubRouteTables/defaultRouteTable'
    hub2DefaultRouteTableId: '${network.outputs.hub2Id}/hubRouteTables/defaultRouteTable'
    vpnSharedKey: vpnSharedKey
  }
}

// Azure Bastion
module bastion 'modules/bastion.bicep' = {
  scope: rg
  name: 'bastion-deployment'
  params: {
    location: region1
    hub1Id: network.outputs.hub1Id
    bastionVnetId: network.outputs.bastionVnetId
    hub1PrivateRouteTableId: routing.outputs.hub1PrivateRouteTableId
    hub1DefaultRouteTableId: routing.outputs.hub1DefaultRouteTableId
  }
  dependsOn: [
    vpn
  ]
}

output vwanId string = network.outputs.vwanId
output hub1Id string = network.outputs.hub1Id
output hub2Id string = network.outputs.hub2Id
output bastionName string = bastion.outputs.bastionName

