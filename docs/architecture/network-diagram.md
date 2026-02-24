# Crucible Network Architecture

## Overview

The Crucible network architecture is designed around a single guiding principle: **containment without compromising visibility**. Every network segment exists for a specific reason. Every firewall rule is intentional. Nothing is left to default behavior.

This document covers the complete network design for Crucible's Tier 1 (Proxmox) deployment. The Azure and Vagrant tiers mirror this segmentation model using provider-native constructs (Azure VNets/NSGs and host-only networks respectively), but the logical design is identical across all three tiers.

If you are deploying Crucible and find yourself wanting to relax a firewall rule or merge two segments for convenience — don't. The isolation boundaries exist to protect both your home network and the integrity of your research. A malware sample that reaches your home network, or telemetry that gets corrupted by unexpected traffic, invalidates your research and potentially causes real harm.

---

## Design Principles

### 1. Least Privilege Networking
Every VM in Crucible has access to exactly what it needs and nothing more. A malware VM in the Detonation VLAN needs to send telemetry to Nexus and receive simulated internet responses from Dark Shrine. It needs nothing else. It gets nothing else.

### 2. Persistent Infrastructure, Ephemeral Research
The Core VLAN — Nexus, Dark Shrine, Arbiter, Witness — is always running. Everything in the Detonation VLAN is ephemeral. Analysis VMs and malware VMs are spun up together for a research task and torn down when it's complete. Your findings live in Nexus, not on the VM.

### 3. Analysis and Detonation Are the Same Task
The analysis workstation and the malware VM are two sides of the same research session. Colocating them in the Detonation VLAN removes the artificial barrier between them, eliminates the need for mediated file transfer, and means the whole research environment — analysis tooling included — is destroyed at the end of a session. No cross-contamination between samples.

### 4. Per-VM Firewall Policies Within Detonation
Analysis VMs and malware VMs live in the same VLAN but have different per-VM firewall rules. Analysis VMs may have controlled outbound access for pulling threat intel or signature updates. Malware VMs have none. Proxmox supports VM-level firewall rules natively — VLAN-level isolation and VM-level policy are complementary, not mutually exclusive.

### 5. Unidirectional Telemetry Flow
Telemetry flows in one direction — from research segments toward the Core VLAN where Nexus lives. Nexus never initiates connections back into the Detonation VLAN for any reason other than initial Elastic Agent enrollment during provisioning.

### 6. Simulated Internet, Never Real Internet
No VM in the Detonation VLAN ever has a path to the real internet. All outbound connection attempts are intercepted by Dark Shrine (INetSim/FakeNet-NG), which simulates realistic internet service responses. This is non-negotiable for malware analysis.

### 7. Sensor Coverage at Every Boundary
Network visibility is achieved through two dedicated Zeek sensors — Arbiter and Witness — positioned to capture traffic at the inter-VLAN boundary and within the Detonation segment respectively.

### 8. Management Plane Separation
The control plane (Proxmox host, Ansible controller) lives in a dedicated Management VLAN that is logically separate from all research traffic. A compromised research VM cannot reach your Proxmox host.

---

## VLAN Layout

| VLAN | Name | Subnet | Purpose |
|---|---|---|---|
| VLAN 10 | Management | 10.10.0.0/24 | Control plane — Proxmox, Ansible |
| VLAN 20 | Core | 10.10.1.0/24 | Persistent research infrastructure |
| VLAN 30 | Detonation | 10.10.2.0/24 | Malware detonation + analysis — most restricted |

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
| Nexus (Kibana + Fleet) | 10.10.1.11 |
| Nexus Console (Jupyter) | 10.10.1.12 |
| Dark Shrine (INetSim/FakeNet-NG) | 10.10.1.20 |
| Arbiter (Zeek North/South) | 10.10.1.30 |
| Gateway | 10.10.1.254 |

**Detonation VLAN (10.10.2.0/24)**
| Host | IP |
|---|---|
| Witness (Zeek Detonation Sensor) | 10.10.2.10 |
| Ephemeral VMs (DHCP pool) | 10.10.2.100 – 10.10.2.200 |
| Gateway | 10.10.2.254 |

---

## Ephemeral VM Templates

The Detonation VLAN uses paired ephemeral templates. You spin up the pair that matches your research task and tear both down when you're done.

| Template | OS | Role | When to Use |
|---|---|---|---|
| `win-malware` | Windows 10/11 or Server | Malware detonation target | PE samples, Windows-targeting malware |
| `win-analysis` | Windows + FLARE-VM | Static and dynamic analysis workstation | Analyzing Windows PE samples |
| `lin-malware` | Ubuntu / Debian | Malware detonation target | ELF binaries, Linux-targeting malware |
| `lin-analysis` | REMnux | Static and dynamic analysis workstation | Analyzing ELF / cross-platform samples |

**Example research session — Windows PE sample:**
1. Spin up `win-malware` and `win-analysis` in the Detonation VLAN
2. Transfer sample directly to `win-analysis` from external source via controlled intake
3. Perform static analysis on `win-analysis` (strings, PE headers, YARA, Ghidra)
4. Copy sample to `win-malware` for detonation
5. Observe telemetry in Nexus — endpoint events from both VMs, network events from Witness
6. Document findings in Nexus Console
7. Tear down both VMs — findings persist in Nexus, VMs do not

**Per-VM firewall policy differences within Detonation VLAN:**

| VM Type | Outbound Allowed | Outbound Denied |
|---|---|---|
| Analysis VM (`win-analysis`, `lin-analysis`) | TCP/9200+8220 → Nexus · Optional: controlled threat intel sources | Real internet · All other outbound |
| Malware VM (`win-malware`, `lin-malware`) | TCP/9200+8220 → Nexus · TCP/80,443 + UDP/53 → Dark Shrine only | Everything else — absolute |

---

## Network Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        HOME NETWORK                              │
│                      (Your existing LAN)                         │
│                                                                  │
│   No Crucible research traffic crosses this boundary.            │
│   Management VLAN accessible for SSH and Proxmox UI only.        │
└──────────────────────────────┬──────────────────────────────────┘
                               │ SSH (TCP/22) · Proxmox UI (TCP/8006)
                               │ Kibana (TCP/5601) · Jupyter (TCP/8888)
                         [FIREWALL]
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│              MANAGEMENT VLAN — 10.10.0.0/24 (VLAN 10)           │
│                                                                  │
│    Proxmox Host (10.10.0.1)    Ansible Controller (10.10.0.10)  │
│                                                                  │
│    Control plane only. Ansible provisions all VMs from here.     │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Provisioning only (Ansible/SSH)
                       [FIREWALL]
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│                  CORE VLAN — 10.10.1.0/24 (VLAN 20)             │
│                                                                  │
│    Nexus — Elasticsearch (10.10.1.10)     ◄── All telemetry     │
│    Nexus — Kibana + Fleet (10.10.1.11)                          │
│    Nexus Console — Jupyter (10.10.1.12)                         │
│    Dark Shrine — INetSim/FakeNet-NG (10.10.1.20)               │
│    Arbiter — Zeek N/S Sensor (10.10.1.30) [promiscuous]        │
│                                                                  │
│    Receives telemetry from Detonation VLAN (one direction).      │
│    Dark Shrine answers all simulated internet requests.          │
│    Arbiter captures all inter-VLAN traffic at the boundary.      │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Telemetry only (one direction → Nexus)
                            │ Simulated internet responses (Dark Shrine)
                       [FIREWALL]
                            │
┌───────────────────────────▼─────────────────────────────────────┐
│              DETONATION VLAN — 10.10.2.0/24 (VLAN 30)           │
│                                                                  │
│    Witness — Zeek Detonation Sensor (10.10.2.10) [promiscuous]  │
│                                                                  │
│    Ephemeral pairs (DHCP — spun up per session, destroyed after):│
│    ┌─────────────────────┐  ┌─────────────────────┐            │
│    │  win-analysis       │  │  win-malware        │            │
│    │  FLARE-VM           │  │  Windows Target     │            │
│    │  Ghidra · YARA      │  │  Elastic Agent      │            │
│    └─────────────────────┘  └─────────────────────┘            │
│    ┌─────────────────────┐  ┌─────────────────────┐            │
│    │  lin-analysis       │  │  lin-malware        │            │
│    │  REMnux             │  │  Linux Target       │            │
│    │  Strings · Binwalk  │  │  Elastic Agent      │            │
│    └─────────────────────┘  └─────────────────────┘            │
│                                                                  │
│    Most restricted segment. Witness sees every packet.           │
│    No real internet — Dark Shrine only.                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Firewall Rules

All traffic not explicitly permitted is denied by default.

### Management VLAN (10.10.0.0/24)
| Direction | Source | Destination | Port/Protocol | Purpose |
|---|---|---|---|---|
| Inbound | Home LAN | 10.10.0.0/24 | TCP/22 | SSH administration |
| Inbound | Home LAN | 10.10.0.1 | TCP/8006 | Proxmox web UI |
| Outbound | 10.10.0.0/24 | 10.10.1.0/24 | Any | Provision Core VMs |
| Outbound | 10.10.0.0/24 | 10.10.2.0/24 | Any | Provision Detonation VMs |

### Core VLAN (10.10.1.0/24)
| Direction | Source | Destination | Port/Protocol | Purpose |
|---|---|---|---|---|
| Inbound | 10.10.2.0/24 | 10.10.1.10 | TCP/9200 | Elastic Agent telemetry |
| Inbound | 10.10.2.0/24 | 10.10.1.10 | TCP/8220 | Fleet enrollment |
| Inbound | Home LAN | 10.10.1.11 | TCP/5601 | Kibana UI |
| Inbound | Home LAN | 10.10.1.12 | TCP/8888 | Jupyter UI |
| Outbound | 10.10.1.20 | 10.10.2.0/24 | TCP/80,443 + UDP/53 | Dark Shrine responses |
| Deny | Any | 10.10.2.0/24 | Any | Core never initiates into Detonation |

### Detonation VLAN (10.10.2.0/24) — VLAN-level rules
| Direction | Source | Destination | Port/Protocol | Purpose |
|---|---|---|---|---|
| Outbound | 10.10.2.0/24 | 10.10.1.10 | TCP/9200 | Elastic Agent telemetry |
| Outbound | 10.10.2.0/24 | 10.10.1.10 | TCP/8220 | Fleet enrollment |
| Inbound | 10.10.0.0/24 | 10.10.2.0/24 | TCP/22, TCP/5985 | SSH/WinRM from Management |
| Deny | 10.10.2.0/24 | Internet | Any | Absolute. No real internet. Ever. |
| Deny | 10.10.2.0/24 | 10.10.0.0/24 | Any | No path to Management |

### Per-VM rules within Detonation (applied at VM level in Proxmox firewall)

**Malware VMs (`win-malware`, `lin-malware`)**
| Direction | Destination | Port/Protocol | Purpose |
|---|---|---|---|
| Outbound | 10.10.1.10 | TCP/9200+8220 | Telemetry only |
| Outbound | 10.10.1.20 | TCP/80,443 + UDP/53 | Simulated internet via Dark Shrine |
| Deny | All other | Any | Everything else denied |

**Analysis VMs (`win-analysis`, `lin-analysis`)**
| Direction | Destination | Port/Protocol | Purpose |
|---|---|---|---|
| Outbound | 10.10.1.10 | TCP/9200+8220 | Telemetry only |
| Outbound | 10.10.1.20 | TCP/80,443 + UDP/53 | Simulated internet via Dark Shrine |
| Outbound | Optional controlled sources | TCP/443 | Threat intel / signature updates (explicit allowlist only) |
| Deny | All other | Any | Everything else denied |

---

## Zeek Sensor Architecture

### Arbiter — North/South Sensor (Core VLAN, 10.10.1.30)

**Placement rationale:** Arbiter sits at the virtual router where all inter-VLAN traffic passes. By operating in promiscuous mode on the Core VLAN bridge it captures all traffic crossing VLAN boundaries — telemetry flows, provisioning traffic, and any anomalous cross-segment communication.

**What Arbiter captures:**
- All telemetry flowing from Detonation VLAN to Nexus
- All provisioning traffic from Management to research segments
- Dark Shrine's simulated responses to Detonation segment requests
- Any unexpected inter-VLAN traffic (misconfigurations, escape attempts)

**Zeek log types enabled:** conn, dns, http, ssl, x509, files, weird

### Witness — Detonation Sensor (Detonation VLAN, 10.10.2.10)

**Placement rationale:** Witness is dedicated entirely to the Detonation VLAN. It sees every packet that any VM in the segment sends or receives — both malware VMs and analysis VMs. Because analysis VMs are ephemeral and colocated with their malware counterpart, Witness provides a complete picture of the entire research session at the network level.

**What Witness captures:**
- Every network connection attempt from detonating samples
- DNS queries (including failed ones — malware often queries C2 before Dark Shrine responds)
- HTTP/HTTPS transactions with Dark Shrine
- Analysis VM network activity (threat intel pulls, tool downloads if permitted)
- Any lateral movement attempts between VMs within the Detonation VLAN
- Failed connection attempts — often as valuable as successful ones

**Zeek log types enabled:** conn, dns, http, ssl, x509, files, weird, notice, intel

**Why intel.log matters on Witness:** The Zeek Intel framework allows you to feed in threat intelligence indicators (IPs, domains, hashes, certificates) and alert when a sample contacts known-bad infrastructure. Seeding Witness with threat intel from your research adds a network-level detection layer.

### Telemetry Pipeline

Both Arbiter and Witness run Elastic Agent alongside Zeek. Zeek outputs logs in JSON format, which Elastic Agent ships to Nexus using the native Zeek integration. All network metadata lands in the same Elasticsearch indices as endpoint telemetry — enabling queries like "show me all processes that made network connections within 5 seconds of this DNS query."

---

## Sample Intake Process

Bringing a malware sample into the environment is a deliberate, controlled process.

1. Spin up the appropriate analysis/malware VM pair in the Detonation VLAN
2. Transfer the sample directly to the analysis VM via Management-plane-mediated file transfer (SCP through Ansible controller) — never via direct path from your home machine into the Detonation VLAN
3. Perform static analysis on the analysis VM — hash verification, strings, PE/ELF header analysis, YARA — before the sample ever touches a live execution environment
4. Copy sample from analysis VM to malware VM within the Detonation VLAN
5. Detonate with Witness running — all wire traffic and endpoint telemetry captured automatically
6. Observe telemetry in Nexus in real time
7. Document findings in Nexus Console
8. Destroy both VMs — findings persist in Nexus, the VMs do not

---

## Azure Tier Equivalent

In the Azure deployment tier this segmentation model is implemented using:

| Proxmox Construct | Azure Equivalent |
|---|---|
| VLAN | Subnet within a VNet |
| Proxmox Firewall Rules | Network Security Groups (NSGs) |
| VM-level firewall | NSG applied at NIC level |
| Promiscuous mode bridge | VNet TAP / Network Watcher packet capture |
| Virtual router | Azure Route Tables with forced tunneling |

> ⚠️ **Azure Note:** Azure does not support promiscuous mode NICs natively. Zeek sensor placement in the Azure tier uses Azure Network Watcher and VNet TAP where available. This is documented in detail in the Azure deployment tier documentation.

---

## Known Limitations and Caveats

### Single-Node vs Multi-Node Proxmox

In a single Proxmox node deployment, all inter-VM traffic stays on the host's virtual bridges — Arbiter and Witness see everything. In a multi-node cluster, traffic between VMs on different physical hosts traverses the physical network and may not be visible to sensors on a different node.

**Mitigation for multi-node deployments:**
- Option 1: Pin all Crucible VMs to a single node using Proxmox affinity rules (simplest)
- Option 2: Deploy Open vSwitch (OVS) with native port mirroring across nodes
- Option 3: Deploy a dedicated monitoring bridge on each node with traffic mirroring

The default Crucible deployment assumes single-node. Multi-node guidance is an advanced topic covered separately.

### Hypervisor Trust Boundary

Crucible's VLAN isolation relies on the Proxmox hypervisor enforcing virtual switch boundaries. A sufficiently privileged VM escape could potentially manipulate this boundary. Crucible mitigates this through defense in depth — host-based firewall on every VM, Elastic Agent visibility into anomalous behavior, and Witness capturing all wire traffic in the Detonation VLAN. For truly air-gapped malware detonation, physical separation on dedicated hardware is the only complete mitigation — this is outside Crucible's scope but worth noting for high-risk samples.

### IPv6

Currently out of scope. All Crucible networking is IPv4. Malware samples that use IPv6 for C2 evasion will have their IPv6 traffic dropped silently — worth noting in research documentation when relevant.

---

*Last updated: 2026*
*Component of: Crucible — A Portable Adversary Research Environment*
*Maintained by: DarkArch0n*
