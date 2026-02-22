# Crucible Network Architecture

## Overview

The Crucible network architecture is designed around a single guiding principle: **containment without compromising visibility**. Every network segment exists for a specific reason. Every firewall rule is intentional. Nothing is left to default behavior.

This document covers the complete network design for Crucible's Tier 1 (Proxmox) deployment. The Azure and Vagrant tiers mirror this segmentation model using provider-native constructs (Azure VNets/NSGs and host-only networks respectively), but the logical design is identical across all three tiers.

If you are deploying Crucible and find yourself wanting to relax a firewall rule or merge two segments for convenience — don't. The isolation boundaries exist to protect both your home network and the integrity of your research. A malware sample that reaches your home network, or telemetry that gets corrupted by unexpected traffic, invalidates your research and potentially causes real harm.

---

## Design Principles

### 1. Least Privilege Networking
Every VM in Crucible has access to exactly what it needs and nothing more. A malware VM in the Detonation VLAN needs to send telemetry to Nexus and receive simulated internet responses from Dark Shrine. It needs nothing else. It gets nothing else.

### 2. Unidirectional Telemetry Flow
Telemetry flows in one direction — from research segments toward the Core VLAN where Nexus lives. Nexus does not initiate connections back into Target or Detonation segments for any reason other than initial Elastic Agent enrollment during provisioning. This ensures a compromised target cannot use the telemetry channel as a path back into the core infrastructure.

### 3. Simulated Internet, Never Real Internet
No VM in the Target or Detonation VLANs ever has a path to the real internet. All outbound connection attempts from these segments are intercepted by Dark Shrine (INetSim/FakeNet-NG), which simulates realistic internet service responses. This is non-negotiable for malware analysis — real C2 communication must never leave your environment.

### 4. Sensor Coverage at Every Boundary
Network visibility is achieved through two dedicated Zeek sensors — Arbiter and Witness — positioned to capture traffic at the inter-VLAN boundary and within the Detonation segment respectively. No research traffic flows through the environment without being observed.

### 5. Management Plane Separation
The control plane (Proxmox host, Ansible controller, SSH access) lives in a dedicated Management VLAN that is logically separate from all research traffic. This means a compromised research VM cannot reach your Proxmox host or disrupt provisioning infrastructure.

---

## VLAN Layout

| VLAN | Name | Subnet | Purpose |
|---|---|---|---|
| VLAN 10 | Management | 10.10.0.0/24 | Control plane — Proxmox, Ansible, SSH |
| VLAN 20 | Core | 10.10.1.0/24 | Persistent research infrastructure |
| VLAN 30 | Analysis | 10.10.2.0/24 | Static and dynamic analysis workstation |
| VLAN 40 | Target | 10.10.3.0/24 | Ephemeral victim targets |
| VLAN 50 | Detonation | 10.10.4.0/24 | Malware detonation — most restricted |

### IP Allocation by Segment

**Management VLAN (10.10.0.0/24)**
| Host | IP |
|---|---|
| Proxmox Host | 10.10.0.1 |
| Ansible Controller | 10.10.0.10 |
| Gateway | 10.10.0.254 |

**Core VLAN (10.10.1.0/24)**
| Host | IP |
|---|---|
| Nexus (Elasticsearch) | 10.10.1.10 |
| Nexus (Kibana) | 10.10.1.11 |
| Nexus Console (Jupyter) | 10.10.1.12 |
| Dark Shrine (INetSim/FakeNet-NG) | 10.10.1.20 |
| Arbiter (Zeek - North/South) | 10.10.1.30 |
| Gateway | 10.10.1.254 |

**Analysis VLAN (10.10.2.0/24)**
| Host | IP |
|---|---|
| Void Prism (REMnux) | 10.10.2.10 |
| Gateway | 10.10.2.254 |

**Target VLAN (10.10.3.0/24)**
| Host | IP |
|---|---|
| Ephemeral Targets (DHCP pool) | 10.10.3.100 - 10.10.3.200 |
| Gateway | 10.10.3.254 |

**Detonation VLAN (10.10.4.0/24)**
| Host | IP |
|---|---|
| Witness (Zeek - Detonation) | 10.10.4.10 |
| Malware VMs (DHCP pool) | 10.10.4.100 - 10.10.4.200 |
| Gateway | 10.10.4.254 |

---

## Network Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        HOME NETWORK                              │
│                      (Your existing LAN)                         │
│                                                                  │
│   No Crucible research traffic crosses this boundary.            │
│   Management VLAN is accessible from here for administration.    │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                        Management access only
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│              MANAGEMENT VLAN — 10.10.0.0/24 (VLAN 10)           │
│                                                                  │
│    Proxmox Host (10.10.0.1)    Ansible Controller (10.10.0.10)  │
│                                                                  │
│    Control plane only. Ansible provisions all VMs from here.     │
│    SSH access to all segments routes through this VLAN.          │
└───────────┬─────────────────────────────────────────────────────┘
            │ Provisioning traffic only
            │ (Ansible, SSH)
            │
┌───────────▼─────────────────────────────────────────────────────┐
│                 CORE VLAN — 10.10.1.0/24 (VLAN 20)              │
│                                                                  │
│    Nexus — Elasticsearch (10.10.1.10)                           │
│    Nexus — Kibana (10.10.1.11)                                  │
│    Nexus Console — Jupyter (10.10.1.12)                         │
│    Dark Shrine — INetSim/FakeNet-NG (10.10.1.20)               │
│    Arbiter — Zeek North/South Sensor (10.10.1.30)              │
│                                                                  │
│    Receives telemetry from all segments (one direction).         │
│    Dark Shrine handles all simulated internet responses.         │
│    Arbiter mirrors and inspects all inter-VLAN traffic.          │
└───────────┬──────────────┬──────────────────┬───────────────────┘
            │              │                  │
     Telemetry only  Telemetry only    Simulated internet
     (one direction) (one direction)   responses only
            │              │                  │
┌───────────▼───┐  ┌────────▼─────────┐  ┌───▼───────────────────┐
│ ANALYSIS VLAN │  │   TARGET VLAN    │  │   DETONATION VLAN     │
│ 10.10.2.0/24  │  │  10.10.3.0/24   │  │   10.10.4.0/24        │
│ (VLAN 30)     │  │  (VLAN 40)      │  │   (VLAN 50)           │
│               │  │                 │  │                        │
│ Void Prism    │  │ Ephemeral       │  │  Malware VMs          │
│ (10.10.2.10)  │  │ Windows         │  │  (DHCP pool)          │
│               │  │ Ephemeral       │  │                        │
│ Static and    │  │ Linux           │  │  Witness — Zeek       │
│ dynamic       │  │ Ephemeral       │  │  (10.10.4.10)         │
│ analysis      │  │ Network OS      │  │                        │
│               │  │                 │  │  Most restricted       │
│ Cannot reach  │  │ No internet     │  │  segment.             │
│ Detonation    │  │ access.         │  │  Witness captures     │
│ directly.     │  │ No path to      │  │  100% of wire         │
│               │  │ Detonation.     │  │  traffic here.        │
└───────────────┘  └─────────────────┘  └───────────────────────┘
```

---

## Firewall Rules

The following rules define allowed traffic between segments. All traffic not explicitly permitted is denied by default. These rules are implemented as Proxmox firewall rules at the cluster level and mirrored as Azure NSG rules in the cloud tier.

### Management VLAN (10.10.0.0/24)
| Direction | Source | Destination | Port/Protocol | Purpose |
|---|---|---|---|---|
| Outbound | 10.10.0.0/24 | 10.10.1.0/24 | Any | Provision Core VMs |
| Outbound | 10.10.0.0/24 | 10.10.2.0/24 | Any | Provision Analysis VMs |
| Outbound | 10.10.0.0/24 | 10.10.3.0/24 | Any | Provision Target VMs |
| Outbound | 10.10.0.0/24 | 10.10.4.0/24 | Any | Provision Detonation VMs |
| Inbound | Home LAN | 10.10.0.0/24 | TCP/22 | SSH administration |
| Inbound | Home LAN | 10.10.0.0/24 | TCP/8006 | Proxmox web UI |

### Core VLAN (10.10.1.0/24)
| Direction | Source | Destination | Port/Protocol | Purpose |
|---|---|---|---|---|
| Inbound | 10.10.2.0/24 | 10.10.1.10 | TCP/9200 | Elastic Agent telemetry from Analysis |
| Inbound | 10.10.3.0/24 | 10.10.1.10 | TCP/9200 | Elastic Agent telemetry from Target |
| Inbound | 10.10.4.0/24 | 10.10.1.10 | TCP/9200 | Elastic Agent telemetry from Detonation |
| Inbound | 10.10.2.0/24 | 10.10.1.10 | TCP/8220 | Fleet enrollment from Analysis |
| Inbound | 10.10.3.0/24 | 10.10.1.10 | TCP/8220 | Fleet enrollment from Target |
| Inbound | 10.10.4.0/24 | 10.10.1.10 | TCP/8220 | Fleet enrollment from Detonation |
| Inbound | Home LAN | 10.10.1.11 | TCP/5601 | Kibana UI access |
| Inbound | Home LAN | 10.10.1.12 | TCP/8888 | Jupyter Notebook access |
| Outbound | 10.10.1.20 | 10.10.4.0/24 | TCP/80,443,53 | Dark Shrine simulated responses |
| Deny | Any | 10.10.3.0/24 | Any | Core never initiates into Target |
| Deny | Any | 10.10.4.0/24 | Any | Core never initiates into Detonation |

### Analysis VLAN (10.10.2.0/24)
| Direction | Source | Destination | Port/Protocol | Purpose |
|---|---|---|---|---|
| Outbound | 10.10.2.10 | 10.10.1.10 | TCP/9200 | Elastic Agent telemetry to Nexus |
| Outbound | 10.10.2.10 | 10.10.1.10 | TCP/8220 | Fleet enrollment |
| Inbound | 10.10.0.0/24 | 10.10.2.10 | TCP/22 | SSH from Management |
| Deny | 10.10.2.0/24 | 10.10.4.0/24 | Any | No direct path to Detonation |
| Deny | 10.10.2.0/24 | 10.10.3.0/24 | Any | No direct path to Target |
| Deny | 10.10.2.0/24 | Internet | Any | No real internet access |

### Target VLAN (10.10.3.0/24)
| Direction | Source | Destination | Port/Protocol | Purpose |
|---|---|---|---|---|
| Outbound | 10.10.3.0/24 | 10.10.1.10 | TCP/9200 | Elastic Agent telemetry to Nexus |
| Outbound | 10.10.3.0/24 | 10.10.1.10 | TCP/8220 | Fleet enrollment |
| Inbound | 10.10.0.0/24 | 10.10.3.0/24 | TCP/22,5985 | SSH/WinRM from Management |
| Deny | 10.10.3.0/24 | 10.10.4.0/24 | Any | No path to Detonation |
| Deny | 10.10.3.0/24 | 10.10.2.0/24 | Any | No path to Analysis |
| Deny | 10.10.3.0/24 | Internet | Any | No real internet access |

### Detonation VLAN (10.10.4.0/24)
| Direction | Source | Destination | Port/Protocol | Purpose |
|---|---|---|---|---|
| Outbound | 10.10.4.0/24 | 10.10.1.10 | TCP/9200 | Elastic Agent telemetry to Nexus |
| Outbound | 10.10.4.0/24 | 10.10.1.10 | TCP/8220 | Fleet enrollment |
| Outbound | 10.10.4.0/24 | 10.10.1.20 | TCP/80,443 | Simulated HTTP/HTTPS to Dark Shrine |
| Outbound | 10.10.4.0/24 | 10.10.1.20 | UDP/53 | Simulated DNS to Dark Shrine |
| Inbound | 10.10.0.0/24 | 10.10.4.0/24 | TCP/22,5985 | SSH/WinRM from Management only |
| Deny | 10.10.4.0/24 | Internet | Any | Absolute. No real internet. Ever. |
| Deny | 10.10.4.0/24 | 10.10.2.0/24 | Any | No path to Analysis |
| Deny | 10.10.4.0/24 | 10.10.3.0/24 | Any | No path to Target |
| Deny | 10.10.4.0/24 | 10.10.0.0/24 | Any | No path to Management |

---

## Zeek Sensor Architecture

### Arbiter — North/South Sensor (Core VLAN, 10.10.1.30)

**Placement rationale:** Arbiter sits at the virtual router where all inter-VLAN traffic passes. By operating in promiscuous mode on the Core VLAN bridge, it captures all traffic crossing VLAN boundaries — telemetry flows, provisioning traffic, and any anomalous cross-segment communication that shouldn't be happening.

**What Arbiter captures:**
- All telemetry flowing from Target and Detonation VLANs to Nexus
- All provisioning traffic from Management to research segments
- Dark Shrine's simulated responses to Detonation segment requests
- Any unexpected inter-VLAN traffic that violates firewall rules (useful for detecting misconfigurations or escape attempts)

**Zeek log types enabled on Arbiter:** conn.log, dns.log, http.log, ssl.log, x509.log, files.log, weird.log

**Why weird.log matters:** Zeek's weird.log captures protocol anomalies — malformed packets, unexpected protocol behavior, connection attempts that don't follow standard patterns. For threat research this is often where the most interesting behavioral signals appear.

### Witness — Detonation Sensor (Detonation VLAN, 10.10.4.10)

**Placement rationale:** Witness is dedicated entirely to the Detonation VLAN. It has a promiscuous mode NIC on the Detonation bridge and sees every packet that any malware VM sends or receives. Because this segment has strict isolation, the signal-to-noise ratio here is extremely high — every connection attempt, every DNS query, every byte transmitted is directly attributable to the sample being analyzed.

**What Witness captures:**
- Every network connection attempt made by a detonating sample
- DNS queries (even failed ones — malware often queries C2 domains before Dark Shrine can respond)
- HTTP/HTTPS transactions with Dark Shrine
- Any protocol behavior that reveals malware capabilities (custom protocols, beaconing patterns, data exfiltration attempts)
- Failed connection attempts — these are often as valuable as successful ones

**Zeek log types enabled on Witness:** conn.log, dns.log, http.log, ssl.log, x509.log, files.log, weird.log, notice.log, intel.log

**Why intel.log matters on Witness:** Zeek's Intel framework allows you to feed in threat intelligence indicators (IPs, domains, hashes, certificates) and generate alerts when a sample contacts known-bad infrastructure. Seeding Witness with threat intel from your research adds another detection layer at the network level.

### Telemetry Pipeline

Both Arbiter and Witness run Elastic Agent alongside Zeek. Zeek outputs logs in JSON format, which Elastic Agent ships to Nexus using the Zeek integration. This means all network metadata lands in the same Elasticsearch indices as your endpoint telemetry — enabling correlation queries like "show me all processes that made network connections within 5 seconds of this DNS query."

```
Witness (Zeek JSON logs)
        │
        ▼
Elastic Agent on Witness
        │
        ▼ TCP/9200
Nexus (Elasticsearch)
        │
        ▼
Kibana / Nexus Console
```

---

## Sample Intake Process

Moving a malware sample from the real world into the Detonation VLAN is a deliberate, controlled process — not a casual file transfer. The following procedure ensures samples never touch your home network or analysis workstation in an unsafe state.

1. Download the sample to Void Prism (Analysis VLAN) via a secure transfer method — password-protected archive, MalwareBazaar API, or similar
2. Perform initial static analysis on Void Prism — hash verification, string extraction, PE header analysis — before the sample ever touches a live execution environment
3. Transfer the sample from Void Prism to the target Detonation VM via a Management-plane-mediated file transfer (SCP through the Ansible controller) — never via a direct network path between Analysis and Detonation
4. Detonate in the Detonation VM with Witness and Elastic Agent running
5. Observe telemetry in Nexus in real time
6. After analysis, snapshot or destroy the Detonation VM — never reuse a detonated VM for a different sample

---

## Azure Tier Equivalent

In the Azure deployment tier, this segmentation model is implemented using:

| Proxmox Construct | Azure Equivalent |
|---|---|
| VLAN | Subnet within a VNet |
| Proxmox Firewall Rules | Network Security Groups (NSGs) |
| Promiscuous mode bridge | VNet TAP / Network Watcher packet capture |
| Virtual router | Azure Route Tables with forced tunneling |

The logical isolation is identical. The implementation differs. Terraform modules for each tier handle this translation transparently — the same Ansible provisioning runs against both.

> ⚠️ **Azure Note:** Azure does not support promiscuous mode NICs natively. Zeek sensor placement in the Azure tier uses Azure Network Watcher and VNet TAP where available, or a dedicated hub VNet with traffic mirroring. This is documented in detail in the Azure deployment tier documentation.

---

## Future Considerations

- **IPv6:** Currently out of scope. All Crucible networking is IPv4. Malware samples that use IPv6 for C2 evasion will have their IPv6 traffic dropped silently — this is a known limitation and worth noting in research documentation when relevant.
- **Wireless simulation:** Not currently in scope but worth considering for research involving mobile malware or WiFi-adjacent TTPs.
- **Inter-environment isolation:** If running multiple simultaneous research environments on the same Proxmox host, each environment should have its own VLAN set with non-overlapping IP ranges. Terraform profiles will handle this via variable input.

---

*Last updated: 2026*
*Component of: Crucible — A Portable Adversary Research Environment*
*Maintained by: DarkArch0n*
