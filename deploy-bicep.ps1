#Requires -Version 7.0

# Azure Virtual WAN Route Tables Lab - Bicep Deployment
# This script deploys the complete Virtual WAN infrastructure using Bicep templates

param(
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
    [string]$SubscriptionId,

    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "vwan-route-tables-lab",
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "westus3",

    [Parameter(Mandatory=$false)]
    [ValidateSet('westus3', 'centralus', 'westcentralus', 'southcentralus')]
    [string]$Location2 = "westus3",
    
    [Parameter(Mandatory=$false)]
    [string]$AdminUsername = "azureuser",

    [Parameter(Mandatory=$false)]
    [string]$VmSize = "Standard_D2ls_v7",
    
    [Parameter(Mandatory=$false)]
    [System.Security.SecureString]$AdminPassword,

    [Parameter(Mandatory=$false)]
    [System.Security.SecureString]$VpnSharedKey,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('Standard', 'Premium')]
    [string]$FirewallSku = "Premium"
)

function ConvertTo-PlainText {
    param([System.Security.SecureString]$SecureValue)

    $pointer = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
    try {
        [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    }
}

# Check if logged into Azure
Write-Host "Checking Azure login..." -ForegroundColor Cyan
$account = az account show 2>$null | ConvertFrom-Json
if (!$account) {
    Write-Host "Not logged in. Please login to Azure..." -ForegroundColor Yellow
    az login
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Azure login failed."
        exit 1
    }
}

az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    Write-Error "Unable to select subscription '$SubscriptionId'. If it belongs to another tenant, run 'az login --tenant <TENANT_ID>' and try again."
    exit 1
}

$account = az account show --subscription $SubscriptionId 2>$null | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or !$account -or $account.id -ne $SubscriptionId) {
    Write-Error "Azure CLI did not confirm the requested subscription '$SubscriptionId'. Deployment stopped."
    exit 1
}

Write-Host "Using subscription: $($account.name) ($($account.id))" -ForegroundColor Green
Write-Host "Tenant: $($account.tenantId)" -ForegroundColor Green

az extension show --name virtual-wan --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "The Azure CLI 'virtual-wan' extension is required. Install it with: az extension add --name virtual-wan --upgrade"
    exit 1
}

$resourceGroupExists = az group exists --name $ResourceGroupName --subscription $SubscriptionId 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Error "Unable to check whether resource group '$ResourceGroupName' exists."
    exit 1
}

if ($resourceGroupExists -eq 'true') {
    $virtualHubNames = @(
        az network vhub list `
            --resource-group $ResourceGroupName `
            --subscription $SubscriptionId `
            --query '[].name' `
            --output tsv
    )

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Unable to inspect '$ResourceGroupName' for existing virtual hubs."
        exit 1
    }

    foreach ($virtualHubName in $virtualHubNames) {
        $routingIntents = @(
            az network vhub routing-intent list `
                --resource-group $ResourceGroupName `
                --vhub $virtualHubName `
                --subscription $SubscriptionId `
                --query '[].name' `
                --output tsv `
                2>$null
        )

        if ($LASTEXITCODE -ne 0) {
            Write-Error "Unable to inspect virtual hub '$virtualHubName' for existing routing intents."
            exit 1
        }

        if ($routingIntents.Count -gt 0) {
            Write-Error "Resource group '$ResourceGroupName' contains routing-intent resources from the original lab. Incremental deployment will not remove them. Use a fresh resource group or delete the old lab resource group first."
            exit 1
        }
    }
}

# Prompt for password if not provided
if (-not $AdminPassword) {
    $AdminPassword = Read-Host -Prompt "Enter VM admin password" -AsSecureString
}

if (-not $VpnSharedKey) {
    $VpnSharedKey = Read-Host -Prompt "Enter VPN pre-shared key" -AsSecureString
}

Write-Host "`nDeployment Parameters:" -ForegroundColor Cyan
Write-Host "  Subscription: $($account.name) ($SubscriptionId)"
Write-Host "  Tenant: $($account.tenantId)"
Write-Host "  Resource Group: $ResourceGroupName"
Write-Host "  Hub 1 Location: $Location"
Write-Host "  Hub 2 Location: $Location2"
Write-Host "  Admin Username: $AdminUsername"
Write-Host "  VM Size: $VmSize"
Write-Host "  Firewall SKU: $FirewallSku"

Write-Host "`nStarting Bicep deployment (this will take approximately 60-90 minutes)..." -ForegroundColor Yellow
Write-Host "Components to deploy:" -ForegroundColor Cyan
Write-Host "  - Virtual WAN with 2 secure hubs"
Write-Host "  - 6 Virtual Networks (Branch, Bastion, 4 Spokes)"
Write-Host "  - 5 Ubuntu VMs"
Write-Host "  - Branch VPN Gateway + 2 Hub VPN Gateways"
Write-Host "  - 2 Azure Firewalls (Premium) with explicit vHub route tables"
Write-Host "  - Azure Bastion with IP-based connection"

$deploymentName = "vwan-securehub-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$previousEnvironment = @{}
$deploymentEnvironment = @{}

try {
    $deploymentEnvironment = @{
        AZURE_RESOURCE_GROUP_NAME = $ResourceGroupName
        AZURE_LOCATION = $Location
        AZURE_LOCATION_2 = $Location2
        AZURE_VM_ADMIN_USERNAME = $AdminUsername
        AZURE_VM_ADMIN_PASSWORD = ConvertTo-PlainText $AdminPassword
        AZURE_VM_SIZE = $VmSize
        AZURE_FIREWALL_SKU = $FirewallSku
        AZURE_VPN_SHARED_KEY = ConvertTo-PlainText $VpnSharedKey
    }

    foreach ($name in $deploymentEnvironment.Keys) {
        $previousEnvironment[$name] = [System.Environment]::GetEnvironmentVariable($name, 'Process')
        [System.Environment]::SetEnvironmentVariable($name, $deploymentEnvironment[$name], 'Process')
    }

    # Deploy using Azure CLI + Bicep
    Write-Host "`nStarting deployment..." -ForegroundColor Cyan
    
    az deployment sub create `
        --subscription $SubscriptionId `
        --name $deploymentName `
        --location $Location `
        --template-file "$PSScriptRoot\main.bicep" `
        --parameters "$PSScriptRoot\main.bicepparam"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✓ Deployment completed successfully!" -ForegroundColor Green
        
        Write-Host "`nNext Steps:" -ForegroundColor Yellow
        Write-Host "1. Navigate to Azure Portal > Bastion"
        Write-Host "2. Connect to each VM using its current private IP address"
        Write-Host "3. Validate effective routes on each vHub connection"
        Write-Host "4. Spoke and branch private/internet traffic routes through Azure Firewall"
    }
    else {
        Write-Host "`n✗ Deployment failed" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "`n✗ Deployment error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
finally {
    foreach ($name in $deploymentEnvironment.Keys) {
        [System.Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process')
    }

    $deploymentEnvironment.Clear()
    $previousEnvironment.Clear()
    $AdminPassword = $null
    $VpnSharedKey = $null
    [System.GC]::Collect()
}
