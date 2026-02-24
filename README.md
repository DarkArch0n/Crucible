# Crucible
### A Portable Adversary Research Environment

Crucible is an open-source, portable adversary research environment designed for threat researchers, detection engineers, and malware analysts. It provides a reproducible, infrastructure-as-code driven lab that can be deployed on bare metal, in the cloud, or locally — without compromising on the fidelity of your research.

Crucible is not a fork of any existing project. It is built from the ground up with a clear research workflow in mind: ingest a sample or define a TTP, execute it in an isolated environment, and centralize all telemetry automatically for analysis and detection development.

---

## Why Crucible?

Existing open-source lab environments are excellent for their intended purposes — Active Directory attack practice, red team ranges, CTF training. Crucible is built specifically for **threat research**. The workflows it supports are:

- **Malware Analysis** — Static and dynamic analysis of samples with automatic telemetry forwarding to a centralized detection stack
- **Adversary Emulation** — ATT&CK-aligned TTP execution against ephemeral victim targets to understand artifact generation
- **Detection Engineering** — Building and validating detection rules against real telemetry produced by real techniques

If your goal is to understand *how* adversaries operate and *what* they leave behind, Crucible is built for you.

---

## Core Design Principles

**1. Persistent Infrastructure, Ephemeral Research**
The Crucible core — your network, your detection stack, your sensors — is always running. Everything in the Detonation VLAN is ephemeral. Analysis VMs and malware VMs are spun up together for a research task and torn down when complete. Your findings live in Nexus, not on the VM.

**2. Analysis and Detonation Are the Same Task**
The analysis workstation and the malware VM are two sides of the same research session. Crucible colocates them in the Detonation VLAN — no mediated file transfer, no artificial network barrier between them. Spin up the pair that matches your research task. Tear both down when done.

**3. Provider-Agnostic via Terraform + Ansible**
Crucible uses Terraform to define infrastructure and Ansible to provision it. The target backend — Proxmox, Azure, or local Vagrant — is a deployment profile, not a fundamental constraint. Your research workflow is identical regardless of where the environment runs.

**4. Telemetry-First**
Every component in Crucible is instrumented by default. Elastic Agent is pre-deployed on all VMs. When you detonate a sample or execute a TTP, the artifacts show up in your Elastic stack automatically — not after manual log collection.

**5. ATT&CK Aligned**
Crucible's emulation and detection workflows are organized around the MITRE ATT&CK framework. Every TTP executed in the environment is mapped to a technique ID. Every detection rule references the technique it covers.

**6. Multi-Platform Targets**
Adversaries don't only target Windows. Crucible supports ephemeral Windows, Linux, macOS, and network OS targets. Spin up the platform relevant to your research.

**7. Network Visibility at Every Boundary**
Two dedicated Zeek sensors — Arbiter and Witness — provide complete network visibility. No research traffic moves through the environment without being observed and forwarded to Nexus.

---

## Architecture Overview

Crucible is organized into two layers: a **Persistent Core** that is always running, and **Ephemeral Research VMs** in the Detonation VLAN that are spun up per research task and destroyed when complete.

### Persistent Core

| Component | Crucible Name | VLAN | Role |
|---|---|---|---|
| Elastic Stack (Elasticsearch + Kibana + Fleet) | **Nexus** | Core | Central hub for all telemetry, detection rules, and research dashboards |
| Jupyter Notebook + Elasticsearch Python client | **Nexus Console** | Core | Research interface for querying, correlating, and documenting findings |
| INetSim / FakeNet-NG | **Dark Shrine** | Core | Simulates internet-facing services. Malware calls home — Dark Shrine answers. No real internet egress. |
| Atomic Red Team Runner | **Maelstrom** | Management | ATT&CK-aligned TTP execution engine |
| Detection Rule Library | **Khala** | N/A | Collective knowledge base of ATT&CK-mapped detection rules built from real Crucible telemetry |
| Zeek North/South Sensor | **Arbiter** | Core | Monitors all inter-VLAN traffic at the virtual router boundary |
| Zeek Detonation Sensor | **Witness** | Detonation | Captures 100% of wire traffic within the Detonation VLAN |

### Ephemeral Research VMs (Detonation VLAN)

Spun up per research task in matched pairs — analysis VM + malware VM. All VMs are pre-instrumented with Elastic Agent. Destroyed when the research session is complete.

| Template | OS | Role |
|---|---|---|
| `win-analysis` | Windows + FLARE-VM | Static and dynamic analysis of Windows samples |
| `win-malware` | Windows 10/11 or Server | Windows malware detonation target |
| `lin-analysis` | REMnux | Static and dynamic analysis of Linux/ELF samples |
| `lin-malware` | Ubuntu / Debian | Linux malware detonation target |

---

## Network Segmentation

Crucible uses three isolated VLANs. The simplified model removes barriers between analysis and detonation — they are the same research task — while maintaining strict isolation from your home network and control plane.

| VLAN | Name | Subnet | Key Hosts |
|---|---|---|---|
| VLAN 10 | Management | 10.10.0.0/24 | Proxmox host, Ansible controller |
| VLAN 20 | Core | 10.10.1.0/24 | Nexus, Dark Shrine, Arbiter |
| VLAN 30 | Detonation | 10.10.2.0/24 | Witness, all ephemeral research VMs |

Analysis VMs and malware VMs share the Detonation VLAN but have different per-VM firewall policies — analysis VMs may have controlled outbound access for threat intel, malware VMs have none beyond Dark Shrine and telemetry.

For full firewall rules, sensor placement rationale, ephemeral VM templates, and sample intake procedures see [docs/architecture/network-diagram.md](docs/architecture/network-diagram.md).

---

## Deployment Tiers

Crucible supports three deployment profiles. Choose based on your available resources.

### Tier 1 — Proxmox (Full Local Deployment)
**Best for:** Researchers with a dedicated homelab or server
**Requirements:** Proxmox VE 8+, 32GB+ RAM recommended, 500GB+ storage

Terraform provisions VMs via the Proxmox provider. Full environment with all persistent core components and support for multiple concurrent ephemeral research pairs. Recommended for malware detonation and resource-intensive analysis.

### Tier 2 — Azure (Cloud Deployment)
**Best for:** Scalable, ephemeral research sessions. Spin up, research, tear down.
**Requirements:** Azure subscription, az CLI, Terraform

Provisions isolated VNets with no public internet egress from research VMs. Designed for cost-conscious use — destroy your environment when your research session ends.

> ⚠️ **Note:** Review Microsoft Azure's Acceptable Use Policy before deploying malware samples in cloud environments. The Azure tier is best suited for adversary emulation and TTP testing. For live malware detonation, the Proxmox or Vagrant tier is recommended.

### Tier 3 — Vagrant (Minimal Local Deployment)
**Best for:** Exploration, testing, low-resource environments
**Requirements:** Vagrant, VMware Workstation or VirtualBox, 16GB+ RAM

A stripped-down single-machine profile. Runs a minimal persistent core with one ephemeral research pair at a time. Functional for TTP emulation and detection rule development.

---

## Research Workflows

### Workflow 1: Malware Sample Analysis
1. Spin up the appropriate analysis/malware VM pair in the Detonation VLAN (`win-analysis` + `win-malware` or `lin-analysis` + `lin-malware`)
2. Transfer sample to the analysis VM via Management-plane-mediated intake
3. Perform static analysis on the analysis VM — strings, PE/ELF headers, YARA, Ghidra
4. Copy sample to the malware VM for detonation
5. **Witness** captures all wire traffic — DNS queries, connection attempts, HTTP transactions
6. Endpoint telemetry forwards automatically to **Nexus**
7. **Dark Shrine** handles all outbound connection attempts — no real internet egress
8. Correlate network and endpoint telemetry in **Nexus**, document in **Nexus Console**
9. Destroy both VMs — findings persist in Nexus

### Workflow 2: TTP Emulation and Detection Development
1. Select a MITRE ATT&CK technique to research
2. Spin up the appropriate ephemeral target VM pair
3. Execute the technique via **Maelstrom** (Atomic Red Team) or manually
4. Observe endpoint and network telemetry in **Nexus**
5. Write a detection rule and add it to **Khala**
6. Validate the rule fires correctly, tune for false positive reduction
7. Document technique, artifacts, and detection logic in **Nexus Console**

---

## Roadmap

- [ ] Proxmox deployment tier (Terraform + Ansible)
- [ ] Azure deployment tier (Terraform + Ansible)
- [ ] Vagrant deployment tier
- [ ] Nexus — Elastic Stack + Fleet persistent core provisioning
- [ ] Dark Shrine — INetSim / FakeNet-NG provisioning
- [ ] Arbiter — Zeek North/South sensor provisioning
- [ ] Witness — Zeek Detonation sensor provisioning
- [ ] Maelstrom — Atomic Red Team integration
- [ ] Nexus Console — Jupyter Notebook + Elasticsearch Python client
- [ ] `win-analysis` ephemeral template (Windows + FLARE-VM)
- [ ] `win-malware` ephemeral template (Windows detonation target)
- [ ] `lin-analysis` ephemeral template (REMnux)
- [ ] `lin-malware` ephemeral template (Linux detonation target)
- [ ] Khala — Initial ATT&CK-aligned detection rule library
- [ ] Ghidra to Elastic artifact export pipeline
- [ ] macOS target support
- [ ] Network OS target support
- [ ] AI layer — MCP servers for Nexus, Khala, and ATT&CK context (see `ai/`)
- [ ] Blog post series documenting research workflows

---

## Minimum Requirements

| Tier | RAM | Storage | CPU |
|---|---|---|---|
| Vagrant (minimal) | 16GB | 100GB | 4 cores |
| Proxmox (recommended) | 32GB | 500GB | 8 cores |
| Proxmox (full) | 64GB | 1TB+ | 16+ cores |
| Azure | N/A (pay per use) | N/A | N/A |

---

## Inspiration and Acknowledgements

Crucible was inspired by the work of the following open-source projects. We are not a fork of any of them, but they shaped how we think about portable lab environments:

- [GOAD (Game of Active Directory)](https://github.com/Orange-Cyberdefense/GOAD) by Orange Cyberdefense
- [Ludus](https://ludus.cloud) — Proxmox-based cyber range framework
- [Atomic Red Team](https://github.com/redcanaryco/atomic-red-team) by Red Canary
- [MITRE ATT&CK](https://attack.mitre.org)
- [Elastic Detection Rules](https://github.com/elastic/detection-rules)
- [Zeek Network Security Monitor](https://zeek.org)
- [FLARE-VM](https://github.com/mandiant/flare-vm) by Mandiant
- [REMnux](https://remnux.org)

---

## Contributing

Crucible is in early development. Contributions, ideas, and feedback are welcome. Please open an issue before submitting a pull request so we can discuss the change in context of the project's direction.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

*Built for threat researchers, by threat researchers.*
