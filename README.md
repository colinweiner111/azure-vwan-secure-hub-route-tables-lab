# Azure vWAN Secure Hub Route Tables Lab

> This lab script is based on work by Daniel Mauser (see *Credits & Source* below).

This repo contains a **Bicep-based deployment** for a two-hub **Virtual WAN** lab with spokes, a branch VNet, VPN gateways, secured hub Azure Firewalls, Log Analytics, and Azure Bastion. Traffic is configured with explicit virtual hub route tables and connection associations.

> **No routing intent resources are deployed.** References to routing intent below apply only to migration protection, documented platform limitations, and credit for the original lab.

## Routing Design

The deployment creates these custom virtual hub route tables:

| Hub | Custom route table | Static routes | Next hop |
|---|---|---|---|
| Hub 1 | `inspectedRouteTable` | `172.16.1.0/24`, `172.16.2.0/24`, and `0.0.0.0/0` | Hub 1 Azure Firewall |
| Hub 1 | `internetOnlyRouteTable` | `0.0.0.0/0` | Hub 1 Azure Firewall |
| Hub 1 | `privateOnlyRouteTable` | RFC 1918 prefixes only | Hub 1 Azure Firewall |
| Hub 2 | `inspectedRouteTable` | `172.16.3.0/24`, `172.16.4.0/24`, and `0.0.0.0/0` | Hub 2 Azure Firewall |
| Hub 2 | `internetOnlyRouteTable` | `0.0.0.0/0` | Hub 2 Azure Firewall |

Both hubs also use their Azure-provided `defaultRouteTable`; the template references these built-in tables rather than creating them.

| Connection | Associated route table | Propagates to | Internet security |
|---|---|---|---|
| Spoke 1 and Spoke 2 VNets | Local `inspectedRouteTable` | `Default`, `spoke-routing`, and `internet-only` labels; explicit local Default ID | Enabled |
| Branch VPN | `defaultRouteTable` | `Default`, `spoke-routing`, and `internet-only` labels; explicit local Default ID | Enabled |
| Bastion VNet | `privateOnlyRouteTable` in Hub 1 | `defaultRouteTable` | Disabled |

Both spokes in each hub associate with the same inspected table. Its static local-spoke routes take precedence over learned routes of the same prefix length, steering same-hub Spoke 1-to-Spoke 2 traffic through the local firewall in both directions. The spoke prefixes are passed from the network module rather than duplicated in the routing module. Internet traffic uses the static `0.0.0.0/0` route to that firewall.

Both inspected tables also carry the shared `spoke-routing` label. Spoke and VPN connections propagate learned prefixes to both tables through that label. Learned branch prefixes (expected `10.100.0.0/16`) are more specific than the default route and do not match the local-spoke firewall routes, so traffic from either spoke to on-premises is intended to bypass inspection. Branch VPN connections remain associated with the built-in `defaultRouteTable`, which learns direct spoke routes for the reverse path. No firewall-steering spoke routes are added to Default, and no forced private SNAT is configured.

The previous `internetOnlyRouteTable` resources and their propagation label are retained for compatibility, but no spokes associate with them. The Bastion table and connection remain unchanged: private prefixes target Hub 1 Firewall and there is no default route, preserving direct control-plane internet access. Bastion data-plane connectivity, especially to remote-hub destinations, still requires regression testing.

**Cross-hub inspection remains unresolved.** Learned remote-spoke routes are retained in the inspected tables for direct inter-hub connectivity; this change does not steer those flows through firewalls. That is an interim connectivity path, not satisfaction of the cross-hub inspection requirement. Microsoft documents Routing Intent as the supported mechanism for inter-hub inspection through security appliances inside managed vWAN hubs. Routing Intent remains excluded from this lab; no unsupported SNAT workaround or cross-hub blocking is introduced.

## Architecture

The diagram below shows the earlier Spoke 2 internet-only checkpoint. Use the routing tables above for the current proposed configuration; the diagram's route associations have not yet been updated.

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
git clone https://github.com/colinweiner111/azure-vwan-secure-hub-route-tables-lab.git
cd azure-vwan-secure-hub-route-tables-lab
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

The selective intra-hub configuration has passed local Bicep compilation and compiled-template routing checks. It has **not been deployed or tested live**. Earlier checkpoint tests passed Spoke 2 internet egress and branch connectivity, but private flows involving Spoke 1 failed; those results do not validate this new configuration.

| Flow | Target behavior | Validation status |
|---|---|---|
| Same-hub Spoke 1 <-> Spoke 2, both hubs | Local firewall in both directions | Pending deployment and live tests |
| All four spokes <-> branch/on-premises | Bypass firewall in both directions | Pending deployment and live tests |
| All four spokes to internet | Local firewall egress | Pending deployment and live tests |
| Cross-hub spoke connectivity | Retain learned direct routes | Pending regression tests; not inspected |
| Cross-hub firewall inspection | Required but not implemented | Unresolved under the no-Routing-Intent constraint |
| Bastion to workload VMs | Existing configuration retained | Pending regression tests |
| Branch internet egress | Existing configuration retained | Passed at earlier checkpoint; pending regression test |

After deployment, verify effective routes in both inspected and Default tables: local spoke /24s must select the firewall only in the inspected tables; branch prefixes must select a VPN path; remote spokes must retain inter-hub reachability. More-specific learned routes could override the intended static paths, so template inspection alone is insufficient.

Test TCP/22 in both initiation directions for each same-hub pair and each spoke/branch pair, plus all cross-hub pairs. Correlate test timestamps and addresses with firewall network logs to confirm same-hub inspection; successful connectivity alone does not prove traversal. Confirm branch bypass using effective routes in both directions and log correlation, not just absence of a log entry. For internet, compare each spoke's observed public egress IP with its local firewall's public IP and test DNS/HTTPS. Recheck Bastion access and branch internet access.

See [Virtual WAN routing policies](https://learn.microsoft.com/azure/virtual-wan/how-to-routing-policies) for the documented inter-hub inspection limitation. Routing Intent is not deployed by this lab.

---

© MIT Licensed. See `LICENSE`.


