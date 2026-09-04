param location1 string
param location2 string
param adminUsername string
@secure()
param adminPassword string
param vmSize string
param branchVnetId string
param spoke1Hub1Id string
param spoke2Hub1Id string
param spoke1Hub2Id string
param spoke2Hub2Id string

// Cloud-init script to install traceroute
var cloudInit = base64('''#cloud-config
package_update: true
packages:
  - traceroute
''')

// Branch VM
resource branchNic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'branch1-vm-nic'
  location: location1
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${branchVnetId}/subnets/main'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource branchVM 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'branch1-vm'
  location: location1
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: 'branch1-vm-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'branch1-vm'
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: cloudInit
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: branchNic.id
        }
      ]
    }
  }
}

// Hub1 Spoke VMs
resource spoke1Hub1Nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'hub1-spoke1-vm-nic'
  location: location1
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${spoke1Hub1Id}/subnets/main'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource spoke1Hub1VM 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'hub1-spoke1-vm'
  location: location1
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: 'hub1-spoke1-vm-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'hub1-spoke1-vm'
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: cloudInit
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: spoke1Hub1Nic.id
        }
      ]
    }
  }
}

resource spoke2Hub1Nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'hub1-spoke2-vm-nic'
  location: location1
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${spoke2Hub1Id}/subnets/main'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource spoke2Hub1VM 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'hub1-spoke2-vm'
  location: location1
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: 'hub1-spoke2-vm-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'hub1-spoke2-vm'
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: cloudInit
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: spoke2Hub1Nic.id
        }
      ]
    }
  }
}

// Hub2 Spoke VMs
resource spoke1Hub2Nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'hub2-spoke1-vm-nic'
  location: location2
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${spoke1Hub2Id}/subnets/main'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource spoke1Hub2VM 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'hub2-spoke1-vm'
  location: location2
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: 'hub2-spoke1-vm-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'hub2-spoke1-vm'
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: cloudInit
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: spoke1Hub2Nic.id
        }
      ]
    }
  }
}

resource spoke2Hub2Nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: 'hub2-spoke2-vm-nic'
  location: location2
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${spoke2Hub2Id}/subnets/main'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource spoke2Hub2VM 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'hub2-spoke2-vm'
  location: location2
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: 'hub2-spoke2-vm-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'hub2-spoke2-vm'
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: cloudInit
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: spoke2Hub2Nic.id
        }
      ]
    }
  }
}

output branchVMId string = branchVM.id
output spoke1Hub1VMId string = spoke1Hub1VM.id
output spoke2Hub1VMId string = spoke2Hub1VM.id
output spoke1Hub2VMId string = spoke1Hub2VM.id
output spoke2Hub2VMId string = spoke2Hub2VM.id
