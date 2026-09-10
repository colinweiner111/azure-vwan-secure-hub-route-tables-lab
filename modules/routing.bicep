param hub1Name string
param hub2Name string
param hub1FirewallId string
param hub2FirewallId string
param spoke1Hub1Id string
param spoke2Hub1Id string
param spoke1Hub2Id string
param spoke2Hub2Id string

resource hub1 'Microsoft.Network/virtualHubs@2023-11-01' existing = {
  name: hub1Name
}

resource hub2 'Microsoft.Network/virtualHubs@2023-11-01' existing = {
  name: hub2Name
}

resource hub1DefaultRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2023-11-01' existing = {
  parent: hub1
  name: 'defaultRouteTable'
}

resource hub2DefaultRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2023-11-01' existing = {
  parent: hub2
  name: 'defaultRouteTable'
}

resource hub1InspectedRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2023-11-01' = {
  parent: hub1
  name: 'inspectedRouteTable'
  properties: {
    labels: [
      'hub1-inspected'
    ]
    routes: [
      {
        name: 'PrivateTrafficToFirewall'
        destinationType: 'CIDR'
        destinations: [
          '10.0.0.0/8'
          '172.16.0.0/12'
          '192.168.0.0/16'
        ]
        nextHopType: 'ResourceId'
        nextHop: hub1FirewallId
      }
      {
        name: 'InternetTrafficToFirewall'
        destinationType: 'CIDR'
        destinations: [
          '0.0.0.0/0'
        ]
        nextHopType: 'ResourceId'
        nextHop: hub1FirewallId
      }
    ]
  }
}

resource hub2InspectedRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2023-11-01' = {
  parent: hub2
  name: 'inspectedRouteTable'
  properties: {
    labels: [
      'hub2-inspected'
    ]
    routes: [
      {
        name: 'PrivateTrafficToFirewall'
        destinationType: 'CIDR'
        destinations: [
          '10.0.0.0/8'
          '172.16.0.0/12'
          '192.168.0.0/16'
        ]
        nextHopType: 'ResourceId'
        nextHop: hub2FirewallId
      }
      {
        name: 'InternetTrafficToFirewall'
        destinationType: 'CIDR'
        destinations: [
          '0.0.0.0/0'
        ]
        nextHopType: 'ResourceId'
        nextHop: hub2FirewallId
      }
    ]
  }
}

resource hub1PrivateRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2023-11-01' = {
  parent: hub1
  name: 'privateOnlyRouteTable'
  properties: {
    labels: [
      'hub1-private-only'
    ]
    routes: [
      {
        name: 'PrivateTrafficToFirewall'
        destinationType: 'CIDR'
        destinations: [
          '10.0.0.0/8'
          '172.16.0.0/12'
          '192.168.0.0/16'
        ]
        nextHopType: 'ResourceId'
        nextHop: hub1FirewallId
      }
    ]
  }
}

resource hub1Spoke1Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-11-01' = {
  parent: hub1
  name: 'hub1-spoke1-conn'
  properties: {
    remoteVirtualNetwork: {
      id: spoke1Hub1Id
    }
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable: {
        id: hub1InspectedRouteTable.id
      }
      propagatedRouteTables: {
        labels: [
          'Default'
        ]
        ids: [
          {
            id: hub1DefaultRouteTable.id
          }
        ]
      }
    }
  }
}

resource hub1Spoke2Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-11-01' = {
  parent: hub1
  name: 'hub1-spoke2-conn'
  properties: {
    remoteVirtualNetwork: {
      id: spoke2Hub1Id
    }
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable: {
        id: hub1DefaultRouteTable.id
      }
      propagatedRouteTables: {
        labels: [
          'Default'
        ]
        ids: [
          {
            id: hub1DefaultRouteTable.id
          }
        ]
      }
    }
  }
}

resource hub2Spoke1Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-11-01' = {
  parent: hub2
  name: 'hub2-spoke1-conn'
  properties: {
    remoteVirtualNetwork: {
      id: spoke1Hub2Id
    }
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable: {
        id: hub2InspectedRouteTable.id
      }
      propagatedRouteTables: {
        labels: [
          'Default'
        ]
        ids: [
          {
            id: hub2DefaultRouteTable.id
          }
        ]
      }
    }
  }
}

resource hub2Spoke2Connection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2023-11-01' = {
  parent: hub2
  name: 'hub2-spoke2-conn'
  properties: {
    remoteVirtualNetwork: {
      id: spoke2Hub2Id
    }
    enableInternetSecurity: true
    routingConfiguration: {
      associatedRouteTable: {
        id: hub2DefaultRouteTable.id
      }
      propagatedRouteTables: {
        labels: [
          'Default'
        ]
        ids: [
          {
            id: hub2DefaultRouteTable.id
          }
        ]
      }
    }
  }
}

output hub1InspectedRouteTableId string = hub1InspectedRouteTable.id
output hub2InspectedRouteTableId string = hub2InspectedRouteTable.id
output hub1PrivateRouteTableId string = hub1PrivateRouteTable.id
output hub1DefaultRouteTableId string = hub1DefaultRouteTable.id
output hub2DefaultRouteTableId string = hub2DefaultRouteTable.id
