# Azure Virtual WAN Custom Route Tables: Selective Inspection and Inter-Hub Limitations

> This lab script is based on work by Daniel Mauser (see *Credits & Source* below).

This repo contains a **Bicep-based deployment** for a two-hub **Virtual WAN** lab with spokes, a branch VNet, VPN gateways, secured hub Azure Firewalls, Log Analytics, and Azure Bastion. Traffic is configured with explicit virtual hub route tables and connection associations.

> **No routing intent resources are deployed.** References to routing intent below apply only to migration protection, documented platform limitations, and credit for the original lab.

## Routing Design

The deployment creates these custom virtual hub route tables:

| Hub | Custom route table | Static routes | Next hop |
|---|---|---|---|
| Hub 1 | `inspectedRouteTable` | RFC 1918 prefixes and `0.0.0.0/0` | Hub 1 Azure Firewall |
| Hub 1 | `internetOnlyRouteTable` | `172.16.1.0/24` and `0.0.0.0/0` | Hub 1 Azure Firewall |
| Hub 1 | `defaultRouteTable` | `172.16.1.0/24` | Hub 1 Azure Firewall |
| Hub 1 | `privateOnlyRouteTable` | RFC 1918 prefixes only | Hub 1 Azure Firewall |
| Hub 2 | `inspectedRouteTable` | RFC 1918 prefixes and `0.0.0.0/0` | Hub 2 Azure Firewall |
| Hub 2 | `internetOnlyRouteTable` | `172.16.3.0/24` and `0.0.0.0/0` | Hub 2 Azure Firewall |
| Hub 2 | `defaultRouteTable` | `172.16.3.0/24` | Hub 2 Azure Firewall |

The template updates each Azure-provided `defaultRouteTable` with its local Spoke 1-to-firewall route.

| Connection | Associated route table | Propagates to | Internet security |
|---|---|---|---|
| Spoke 1 VNets | Local `inspectedRouteTable` | `Default` and `internet-only` labels; explicit local Default ID | Enabled |
| Spoke 2 VNets | Local `internetOnlyRouteTable` | `Default` and `internet-only` labels; explicit local Default ID | Enabled |
| Branch VPN | Local `defaultRouteTable` | `Default` and `internet-only` labels; explicit local Default ID | Enabled |
| Bastion VNet | `privateOnlyRouteTable` in Hub 1 | `defaultRouteTable` | Disabled |

Spoke 1 in each hub associates with the local inspected table, which sends RFC 1918 and internet traffic to the local firewall. Spoke 2 associates with the local internet-only table. The local internet-only and Default tables each send traffic destined for the local Spoke 1 prefix to the firewall, while more-specific learned Spoke 2 and on-premises routes use their direct paths. The VPN connection must remain associated with Default because Azure does not permit branch connections to associate with custom route tables. These reciprocal routes keep same-hub Spoke 1-to-Spoke 2 and branch-to-Spoke 1 traffic symmetric through the local firewall while preserving the Spoke 2 branch bypass.

The Bastion table and connection remain unchanged: private prefixes target Hub 1 Firewall and there is no default route, preserving direct control-plane internet access. Bastion data-plane connectivity, especially to remote-hub destinations, still requires regression testing.

**Cross-hub inspection remains unresolved.** Learned remote-spoke routes retain direct inter-hub connectivity when the destination is Spoke 2, but all tested flows whose destination is Spoke 1 fail because inter-hub ingress does not use the local Default-table firewall route. Microsoft documents Routing Intent as the supported mechanism for inter-hub inspection through security appliances inside managed vWAN hubs. Routing Intent remains excluded from this lab; no unsupported SNAT workaround is introduced.

## Architecture

The diagram shows the separate Spoke 1 inspected and Spoke 2 internet-only route-table associations.

![Lab Architecture](image/vwan-02-lab-01.svg?v=2)

## Prerequisites

### Requirements

- **PowerShell 7+** — Run the deployment script with `pwsh`. Windows PowerShell 5.1 is not supported.
- **Azure Subscription** — An active Azure subscription with sufficient quota for the resources deployed
- **RBAC role at subscription scope** — **Contributor** is sufficient; **Owner** also works. Resource-group-only access is not sufficient because the subscription-scoped template creates the resource group.
- **Azure CLI with Bicep support** — The deployment script invokes `az deployment sub create`
- **Azure CLI Virtual WAN extension** — The migration guard checks for routing intent left by an earlier version using the preview `az network vhub routing-intent list` command:
  ```powershell
  az extension add --name virtual-wan --upgrade
  ```
- Logged in to Azure CLI. When deploying to another tenant, specify its tenant ID or verified domain during login:
  ```powershell
  az login --tenant "<TENANT_ID_OR_DOMAIN>"
  ```

### Required Resource Providers

The subscription must have these resource providers registered:

- `Microsoft.Network`
- `Microsoft.Compute`
- `Microsoft.OperationalInsights`
- `Microsoft.Insights`

Each virtual hub uses a `/22` address space, the minimum size required for Azure Firewall in Virtual WAN. Virtual hub address prefixes can't be changed after creation, so an older deployment with `/24` hubs must be deleted and recreated.

## Getting Started

### Clone the Repository

```powershell
git clone https://github.com/colinweiner111/azure-vwan-selective-spoke-inspection-lab.git
cd azure-vwan-selective-spoke-inspection-lab
```

## Deployment

Use the PowerShell deployment script:

```powershell
.\deploy-bicep.ps1 -SubscriptionId <subscription-id> -ResourceGroupName <your-rg-name> -Location westus3 -Location2 centralus
```

Example:
```powershell
.\deploy-bicep.ps1 -SubscriptionId 00000000-0000-0000-0000-000000000000 -ResourceGroupName vwan-lab-rg -Location westus3 -Location2 centralus
```

The script will:
1. Select and verify the exact subscription supplied with `-SubscriptionId`
2. If the target resource group already exists, check it for routing intent left by the original design
3. Deploy the subscription-scoped Bicep template, which creates the resource group
4. Prompt securely for the VM admin password and VPN pre-shared key if not provided

> **Use a fresh resource group when migrating from the original lab.** Azure Resource Manager deployments are incremental and do not delete its routing intent resources. The deployment script refuses to continue if it finds one. This route-table version itself does not create routing intent.

### Required Parameter

- `-SubscriptionId`: Azure subscription GUID to select, verify, and use for all resource checks and deployment operations

### Optional Parameters

- `-ResourceGroupName`: Resource group name (default: `vwan-route-tables-lab`)
- `-Location`: Hub 1, branch, and Bastion region (default: `westus3`)
- `-Location2`: Hub 2 region: `westus3`, `centralus`, `westcentralus`, or `southcentralus` (default: `westus3`)
- `-AdminUsername`: VM administrator username (default: `azureuser`)
- `-VmSize`: VM SKU for all five Linux VMs (default: `Standard_D2ls_v7`); override this when regional capacity requires another SKU
- `-AdminPassword`: VM administrator password as a `SecureString`
- `-VpnSharedKey`: VPN pre-shared key as a `SecureString`
- `-FirewallSku`: `Standard` or `Premium` (default: `Premium`)

For non-interactive use, construct the secure parameters before invoking the script:

```powershell
$adminPassword = ConvertTo-SecureString $env:AZURE_VM_ADMIN_PASSWORD -AsPlainText -Force
$vpnSharedKey = ConvertTo-SecureString $env:AZURE_VPN_SHARED_KEY -AsPlainText -Force
./deploy-bicep.ps1 -SubscriptionId <subscription-id> -AdminPassword $adminPassword -VpnSharedKey $vpnSharedKey
```

## What Gets Deployed

- vWAN + two vHubs
- Two spokes per hub
- Branch site with VPN Gateway (BGP)
- Azure Firewall (Hub) + Policy per hub
- Log Analytics Workspaces + dedicated resource-specific diagnostic tables for all Azure Firewall log categories and metrics
- Two custom `inspectedRouteTable` tables, two retained `internetOnlyRouteTable` tables, one Hub 1 `privateOnlyRouteTable`, and explicit connection associations and propagations
- **Azure Bastion — provides browser-based RDP/SSH access to all VMs (both hubs and branch)**
- **5 Ubuntu VMs:**
  - branch1-vm (in branch VNet)
  - hub1-spoke1-vm, hub1-spoke2-vm (in Hub 1 spokes)
  - hub2-spoke1-vm, hub2-spoke2-vm (in Hub 2 spokes)

## Default Configuration

- **Username**: `azureuser`
- **Password**: Prompted during deployment (set a strong password)
- **Regions**: Both hubs in `westus3` by default. Cross-region Hub 2 placement is optional and has not been validated end to end.
- **VM Size**: `Standard_D2ls_v7`
- **Firewall SKU**: Premium by default
- **VPN pre-shared key**: Prompted during deployment

## VM Network Information

| VM Name | VNet | Subnet Range |
|---------|------|--------------|
| branch1-vm | branch1 | 10.100.0.0/24 |
| hub1-spoke1-vm | hub1-spoke1 | 172.16.1.0/27 |
| hub1-spoke2-vm | hub1-spoke2 | 172.16.2.0/27 |
| hub2-spoke1-vm | hub2-spoke1 | 172.16.3.0/27 |
| hub2-spoke2-vm | hub2-spoke2 | 172.16.4.0/27 |

*VMs receive dynamic IPs within their respective subnets*

## Accessing VMs via Azure Bastion

Azure Bastion provides browser-based SSH access to the lab's Ubuntu VMs without assigning public IPs to those VMs.

In this lab, the Hub 1 private-only route table sends Bastion-to-VM traffic through Azure Firewall. The standard Bastion "Connect to VM" flow assumes direct VNet peering, so use an IP-based connection.

As a result, Bastion must use **"Connect via IP address"**, explicitly targeting the VM's private IP so traffic can traverse the vWAN routing fabric and firewall as intended.

> **Important:** The Bastion connection is associated with `privateOnlyRouteTable` and has `enableInternetSecurity` disabled. Do not add a default route to that table; doing so can break Bastion control-plane connectivity.
>
> See: [Azure Bastion FAQ — Virtual WAN](https://learn.microsoft.com/azure/bastion/bastion-faq#vwan)

> **Lab-only firewall policy:** The deployed `AnytoAny` network rule already permits SSH, RDP, and all other traffic. Replace it with least-privilege rules before adapting this lab for a production environment.

> **References:**
> - [Connect to a VM via IP address (Microsoft Docs)](https://learn.microsoft.com/azure/bastion/connect-ip-address) — Official guide for using Bastion's IP-based connection feature (requires Standard SKU)
> - [Azure Bastion Routing in Virtual WAN (Jose Moreno)](https://blog.cloudtrooper.net/2022/09/17/azure-bastion-routing-in-virtual-wan/) — Deep dive into Bastion placement options and routing behavior in vWAN topologies

### Using Azure Portal (IP-based connection)
1. Navigate to **Azure Portal → Bastions**
2. Select **SharedBastion**
3. Under **Connect**, select **Connection Settings**
4. Choose **Connect via IP address**
5. Enter the **private IP address** of the target VM (see [VM Network Information](#vm-network-information) or check the VM's network interface)
6. Enter username: `azureuser`
7. Enter the password you set during deployment
8. Click **Connect**

> 💡 **Tip:** Bastion Standard SKU is required for IP-based connections. This lab deploys Standard by default.

## Cleanup

When finished, delete the resource group:
```powershell
az group delete --subscription <subscription-id> --name <your-rg> --yes --no-wait
```

## Validation

The selective configuration passed local Bicep compilation, compiled-template routing checks, deployment to `vwan-lab-002_rg`, and live TCP/22 testing. The latest complete test ran from `2026-09-14T14:42:34Z` through `2026-09-14T14:43:14Z`. Dedicated `AZFWNetworkRule` logs were correlated with that window to distinguish inspected flows from bypassed flows.

### Intra-hub paths

| Path | Result | Firewall evidence |
|---|---|---|
| Hub 1 Spoke 1 -> Hub 1 Firewall -> Hub 1 Spoke 2 | PASS | Hub 1 Firewall logged `Allow` |
| Hub 1 Spoke 2 -> Hub 1 Firewall -> Hub 1 Spoke 1 | PASS | Hub 1 Firewall logged `Allow` |
| Hub 2 Spoke 1 -> Hub 2 Firewall -> Hub 2 Spoke 2 | PASS | Hub 2 Firewall logged `Allow` |
| Hub 2 Spoke 2 -> Hub 2 Firewall -> Hub 2 Spoke 1 | PASS | Hub 2 Firewall logged `Allow` |

### Branch paths

| Path | Result | Firewall evidence |
|---|---|---|
| Branch -> VPN -> Hub 1 Firewall -> Hub 1 Spoke 1 | PASS | Hub 1 Firewall logged `Allow` |
| Hub 1 Spoke 1 -> Hub 1 Firewall -> VPN -> Branch | PASS | Hub 1 Firewall logged `Allow` |
| Branch -> VPN -> Hub 1 Spoke 2 | PASS | Firewall bypass; learned VPN route used |
| Hub 1 Spoke 2 -> VPN -> Branch | PASS | Firewall bypass; learned VPN route used |
| Branch -> VPN -> Hub 2 Firewall -> Hub 2 Spoke 1 | PASS | Hub 2 Firewall logged `Allow` |
| Hub 2 Spoke 1 -> Hub 2 Firewall -> VPN -> Branch | PASS | Hub 2 Firewall logged `Allow` |
| Branch -> VPN -> Hub 2 Spoke 2 | PASS | Firewall bypass; learned VPN route used |
| Hub 2 Spoke 2 -> VPN -> Branch | PASS | Firewall bypass; learned VPN route used |

### Inter-hub paths

| Path | Result | Explanation |
|---|---|---|
| Hub 1 Spoke 1 -> Hub 1 Firewall -> Hub 2 -> Hub 2 Spoke 2 | PASS | Source Spoke 1 is inspected by Hub 1 Firewall |
| Hub 1 Spoke 2 -> Hub 1 -> Hub 2 -> Hub 2 Spoke 2 | PASS | Direct inter-hub path; firewall bypass |
| Hub 2 Spoke 1 -> Hub 2 Firewall -> Hub 1 -> Hub 1 Spoke 2 | PASS | Source Spoke 1 is inspected by Hub 2 Firewall |
| Hub 2 Spoke 2 -> Hub 2 -> Hub 1 -> Hub 1 Spoke 2 | PASS | Direct inter-hub path; firewall bypass |
| Hub 1 Spoke 1 -> Hub 1 Firewall -> Hub 2 -> Hub 2 Spoke 1 | EXPECTED FAIL | Return path traverses Hub 2 Firewall; different stateful firewalls see opposite sides of the session |
| Hub 1 Spoke 2 -> Hub 1 -> Hub 2 -> Hub 2 Spoke 1 | EXPECTED FAIL | Return path traverses Hub 2 Firewall, which did not see the initiating packet |
| Hub 2 Spoke 1 -> Hub 2 Firewall -> Hub 1 -> Hub 1 Spoke 1 | EXPECTED FAIL | Return path traverses Hub 1 Firewall; different stateful firewalls see opposite sides of the session |
| Hub 2 Spoke 2 -> Hub 2 -> Hub 1 -> Hub 1 Spoke 1 | EXPECTED FAIL | Return path traverses Hub 1 Firewall, which did not see the initiating packet |

### Internet paths

| Path | Result | Firewall evidence |
|---|---|---|
| Hub 1 Spoke 1 -> Hub 1 Firewall -> internet (`20.106.94.178`) | PASS | Hub 1 Firewall logged allowed HTTPS traffic |
| Hub 1 Spoke 2 -> Hub 1 Firewall -> internet (`20.106.94.178`) | PASS | Hub 1 Firewall logged allowed HTTPS traffic |
| Hub 2 Spoke 1 -> Hub 2 Firewall -> internet (`20.118.175.83`) | PASS | Hub 2 Firewall logged allowed HTTPS traffic |
| Hub 2 Spoke 2 -> Hub 2 Firewall -> internet (`20.118.175.83`) | PASS | Hub 2 Firewall logged allowed HTTPS traffic |

The current configuration provides symmetric same-hub inspection, symmetric branch-to-Spoke 1 inspection, Spoke 2 branch bypass, and local firewall internet egress. Inter-hub flows whose destination is Spoke 1 remain asymmetric and fail. Full symmetric inter-hub firewall inspection is not supported by these custom route tables alone without Routing Intent.

Test TCP/22 in both initiation directions for each same-hub pair and each spoke/branch pair, plus all cross-hub pairs. Correlate test timestamps and addresses with firewall network logs to confirm same-hub inspection; successful connectivity alone does not prove traversal. Confirm branch bypass using effective routes in both directions and log correlation, not just absence of a log entry. For internet, compare each spoke's observed public egress IP with its local firewall's public IP and test DNS/HTTPS. Recheck Bastion access and branch internet access.

See [Virtual WAN routing policies](https://learn.microsoft.com/azure/virtual-wan/how-to-routing-policies) for the documented inter-hub inspection limitation. Routing Intent is not deployed by this lab.

---

© MIT Licensed. See `LICENSE`.


