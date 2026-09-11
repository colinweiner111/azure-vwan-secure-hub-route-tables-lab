param location1 string
param location2 string
param vwanName string
param hub1Name string
param hub2Name string
param branchVnetId string
param hub1Id string
param hub2Id string
param hub1DefaultRouteTableId string
param hub2DefaultRouteTableId string
@secure()
param vpnSharedKey string

// Branch VPN Gateway
resource branchPublicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: 'branch1-vpngw-pip-az'
  location: location1
  zones: [
    '1'
    '2'
    '3'
  ]
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource branchVpnGateway 'Microsoft.Network/virtualNetworkGateways@2023-11-01' = {
  name: 'branch1-vpngw'
  location: location1
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    sku: {
      name: 'VpnGw1AZ'
      tier: 'VpnGw1AZ'
    }
    enableBgp: true
    bgpSettings: {
      asn: 65010
    }
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${branchVnetId}/subnets/GatewaySubnet'
          }
          publicIPAddress: {
            id: branchPublicIp.id
          }
        }
      }
    ]
  }
}

// Hub VPN Gateways
resource hub1VpnGw 'Microsoft.Network/vpnGateways@2023-11-01' = {
  name: '${hub1Name}-vpngw'
  location: location1
  properties: {
    virtualHub: {
      id: hub1Id
    }
    bgpSettings: {
      asn: 65515
    }
  }
}

resource hub2VpnGw 'Microsoft.Network/vpnGateways@2023-11-01' = {
  name: '${hub2Name}-vpngw'
  location: location2
  properties: {
    virtualHub: {
      id: hub2Id
    }
    bgpSettings: {
      asn: 65515
    }
  }
}

// VPN Site for branch1
resource vpnSite 'Microsoft.Network/vpnSites@2023-11-01' = {
  name: 'site-branch1'
  location: location1
  properties: {
    virtualWan: {
      id: resourceId('Microsoft.Network/virtualWans', vwanName)
    }
    deviceProperties: {
      deviceVendor: 'Microsoft'
      deviceModel: 'Azure'
      linkSpeedInMbps: 50
    }
    vpnSiteLinks: [
      {
        name: 'link1'
        properties: {
          ipAddress: branchPublicIp.properties.ipAddress
          bgpProperties: {
            asn: 65010
            bgpPeeringAddress: branchVpnGateway.properties.bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]
          }
          linkProperties: {
            linkSpeedInMbps: 50
          }
        }
      }
    ]
  }
}

// Hub1 to Branch Connection
resource hub1BranchConn 'Microsoft.Network/vpnGateways/vpnConnections@2023-11-01' = {
  parent: hub1VpnGw
  name: 'site-branch1-conn'
  properties: {
    remoteVpnSite: {
      id: vpnSite.id
    }
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable: {
        id: hub1DefaultRouteTableId
      }
      propagatedRouteTables: {
        labels: [
          'Default'
          'internet-only'
          'spoke-routing'
        ]
        ids: [
          {
            id: hub1DefaultRouteTableId
          }
        ]
      }
    }
    vpnLinkConnections: [
      {
        name: 'link1'
        properties: {
          vpnSiteLink: {
            id: '${vpnSite.id}/vpnSiteLinks/link1'
          }
          sharedKey: vpnSharedKey
          enableBgp: true
        }
      }
    ]
  }
}

// Hub2 to Branch Connection
resource hub2BranchConn 'Microsoft.Network/vpnGateways/vpnConnections@2023-11-01' = {
  parent: hub2VpnGw
  name: 'site-branch1-conn'
  properties: {
    remoteVpnSite: {
      id: vpnSite.id
    }
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable: {
        id: hub2DefaultRouteTableId
      }
      propagatedRouteTables: {
        labels: [
          'Default'
          'internet-only'
          'spoke-routing'
        ]
        ids: [
          {
            id: hub2DefaultRouteTableId
          }
        ]
      }
    }
    vpnLinkConnections: [
      {
        name: 'link1'
        properties: {
          vpnSiteLink: {
            id: '${vpnSite.id}/vpnSiteLinks/link1'
          }
          sharedKey: vpnSharedKey
          enableBgp: true
        }
      }
    ]
  }
}

// Local Gateways for Hub1
resource lngHub1Gw1 'Microsoft.Network/localNetworkGateways@2023-11-01' = {
  name: 'lng-${hub1Name}-gw1'
  location: location1
  properties: {
    gatewayIpAddress: hub1VpnGw.properties.bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]
    bgpSettings: {
      asn: 65515
      bgpPeeringAddress: hub1VpnGw.properties.bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]
    }
  }
}

resource lngHub1Gw2 'Microsoft.Network/localNetworkGateways@2023-11-01' = {
  name: 'lng-${hub1Name}-gw2'
  location: location1
  properties: {
    gatewayIpAddress: hub1VpnGw.properties.bgpSettings.bgpPeeringAddresses[1].tunnelIpAddresses[0]
    bgpSettings: {
      asn: 65515
      bgpPeeringAddress: hub1VpnGw.properties.bgpSettings.bgpPeeringAddresses[1].defaultBgpIpAddresses[0]
    }
  }
}

// Local Gateways for Hub2
resource lngHub2Gw1 'Microsoft.Network/localNetworkGateways@2023-11-01' = {
  name: 'lng-${hub2Name}-gw1'
  location: location1
  properties: {
    gatewayIpAddress: hub2VpnGw.properties.bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]
    bgpSettings: {
      asn: 65515
      bgpPeeringAddress: hub2VpnGw.properties.bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]
    }
  }
}

resource lngHub2Gw2 'Microsoft.Network/localNetworkGateways@2023-11-01' = {
  name: 'lng-${hub2Name}-gw2'
  location: location1
  properties: {
    gatewayIpAddress: hub2VpnGw.properties.bgpSettings.bgpPeeringAddresses[1].tunnelIpAddresses[0]
    bgpSettings: {
      asn: 65515
      bgpPeeringAddress: hub2VpnGw.properties.bgpSettings.bgpPeeringAddresses[1].defaultBgpIpAddresses[0]
    }
  }
}

// VPN Connections from Branch to Hubs
resource branchToHub1Gw1Conn 'Microsoft.Network/connections@2023-11-01' = {
  name: 'branch1-to-${hub1Name}-gw1'
  location: location1
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: any({
      id: branchVpnGateway.id
    })
    localNetworkGateway2: any({
      id: lngHub1Gw1.id
    })
    sharedKey: vpnSharedKey
    enableBgp: true
  }
}

resource branchToHub1Gw2Conn 'Microsoft.Network/connections@2023-11-01' = {
  name: 'branch1-to-${hub1Name}-gw2'
  location: location1
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: any({
      id: branchVpnGateway.id
    })
    localNetworkGateway2: any({
      id: lngHub1Gw2.id
    })
    sharedKey: vpnSharedKey
    enableBgp: true
  }
}

resource branchToHub2Gw1Conn 'Microsoft.Network/connections@2023-11-01' = {
  name: 'branch1-to-${hub2Name}-gw1'
  location: location1
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: any({
      id: branchVpnGateway.id
    })
    localNetworkGateway2: any({
      id: lngHub2Gw1.id
    })
    sharedKey: vpnSharedKey
    enableBgp: true
  }
}

resource branchToHub2Gw2Conn 'Microsoft.Network/connections@2023-11-01' = {
  name: 'branch1-to-${hub2Name}-gw2'
  location: location1
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: any({
      id: branchVpnGateway.id
    })
    localNetworkGateway2: any({
      id: lngHub2Gw2.id
    })
    sharedKey: vpnSharedKey
    enableBgp: true
  }
}

output branchVpnGatewayId string = branchVpnGateway.id
output hub1VpnGwId string = hub1VpnGw.id
output hub2VpnGwId string = hub2VpnGw.id
output vpnSiteId string = vpnSite.id
