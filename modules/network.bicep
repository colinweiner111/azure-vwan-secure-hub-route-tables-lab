param location1 string
param location2 string
param vwanName string
param hub1Name string
param hub2Name string

// Virtual WAN
resource vwan 'Microsoft.Network/virtualWans@2023-11-01' = {
  name: vwanName
  location: location1
  properties: {
    type: 'Standard'
    allowBranchToBranchTraffic: true
  }
}

// Virtual Hubs
resource hub1 'Microsoft.Network/virtualHubs@2023-11-01' = {
  name: hub1Name
  location: location1
  properties: {
    addressPrefix: '192.168.0.0/22'
    virtualWan: {
      id: vwan.id
    }
    sku: 'Standard'
    hubRoutingPreference: 'ASPath'
  }
}

resource hub2 'Microsoft.Network/virtualHubs@2023-11-01' = {
  name: hub2Name
  location: location2
  properties: {
    addressPrefix: '192.168.4.0/22'
    virtualWan: {
      id: vwan.id
    }
    sku: 'Standard'
    hubRoutingPreference: 'ASPath'
  }
}

// Branch VNET
resource branchVnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'branch1'
  location: location1
  properties: {
    addressSpace: {
      addressPrefixes: ['10.100.0.0/16']
    }
  }
}

// Bastion VNET
resource bastionVnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'bastion-vnet'
  location: location1
  properties: {
    addressSpace: {
      addressPrefixes: ['10.200.0.0/24']
    }
  }
}

// Spoke VNETs
resource spoke1Hub1 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'hub1-spoke1'
  location: location1
  properties: {
    addressSpace: {
      addressPrefixes: ['172.16.1.0/24']
    }
  }
}

resource spoke2Hub1 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'hub1-spoke2'
  location: location1
  properties: {
    addressSpace: {
      addressPrefixes: ['172.16.2.0/24']
    }
  }
}

resource spoke1Hub2 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'hub2-spoke1'
  location: location2
  properties: {
    addressSpace: {
      addressPrefixes: ['172.16.3.0/24']
    }
  }
}

resource spoke2Hub2 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: 'hub2-spoke2'
  location: location2
  properties: {
    addressSpace: {
      addressPrefixes: ['172.16.4.0/24']
    }
  }
}

// NSGs
resource nsgHub1 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'default-nsg-${hub1Name}-${location1}'
  location: location1
  properties: {
    securityRules: [
      {
        name: 'allow-bastion-ssh'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.200.0.0/26'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'Allow SSH from Bastion'
        }
      }
    ]
  }
}

resource nsgHub2 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: 'default-nsg-${hub2Name}-${location2}'
  location: location2
  properties: {
    securityRules: [
      {
        name: 'allow-bastion-ssh'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '10.200.0.0/26'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
          description: 'Allow SSH from Bastion'
        }
      }
    ]
  }
}

// NSG Associations
resource spoke1Hub1Nsg 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: spoke1Hub1
  name: 'main'
  properties: {
    addressPrefix: '172.16.1.0/27'
    networkSecurityGroup: {
      id: nsgHub1.id
    }
  }
}

resource spoke2Hub1Nsg 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: spoke2Hub1
  name: 'main'
  properties: {
    addressPrefix: '172.16.2.0/27'
    networkSecurityGroup: {
      id: nsgHub1.id
    }
  }
}

resource spoke1Hub2Nsg 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: spoke1Hub2
  name: 'main'
  properties: {
    addressPrefix: '172.16.3.0/27'
    networkSecurityGroup: {
      id: nsgHub2.id
    }
  }
}

resource spoke2Hub2Nsg 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: spoke2Hub2
  name: 'main'
  properties: {
    addressPrefix: '172.16.4.0/27'
    networkSecurityGroup: {
      id: nsgHub2.id
    }
  }
}

resource branchNsg 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: branchVnet
  name: 'main'
  properties: {
    addressPrefix: '10.100.0.0/24'
    networkSecurityGroup: {
      id: nsgHub1.id
    }
  }
}

resource branchGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = {
  parent: branchVnet
  name: 'GatewaySubnet'
  properties: {
    addressPrefix: '10.100.255.0/27'
  }
  dependsOn: [
    branchNsg
  ]
}

output vwanId string = vwan.id
output hub1Id string = hub1.id
output hub2Id string = hub2.id
output branchVnetId string = branchVnet.id
output bastionVnetId string = bastionVnet.id
output spoke1Hub1Id string = spoke1Hub1.id
output spoke2Hub1Id string = spoke2Hub1.id
output spoke1Hub2Id string = spoke1Hub2.id
output spoke2Hub2Id string = spoke2Hub2.id
output nsgHub1Id string = nsgHub1.id
output nsgHub2Id string = nsgHub2.id
