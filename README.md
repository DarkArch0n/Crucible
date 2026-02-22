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

**1. Persistent Infrastructure, Ephemeral Targets**
The Crucible core — your network, your detection stack, your analysis workstation — is always running. The victim targets (Windows, Linux, macOS, network devices) are spun up per research task and torn down when you're done. This keeps resource consumption honest and mirrors how real research engagements work.

**2. Provider-Agnostic via Terraform + Ansible**
Crucible uses Terraform to define infrastructure and Ansible to provision it. The target backend — Proxmox, Azure, or local Vagrant — is a deployment profile, not a fundamental constraint. Your research workflow is identical regardless of where the environment runs.

**3. Telemetry-First**
Every component in Crucible is instrumented by default. Elastic Agent is pre-deployed on all targets. When you detonate a sample or execute a TTP, the artifacts show up in your Elastic stack automatically — not after manual log collection.

**4. ATT&CK Aligned**
Crucible's emulation and detection workflows are organized around the MITRE ATT&CK framework. Every TTP executed in the environment is mapped to a technique ID. Every detection rule references the technique it covers.

**5. Multi-Platform Targets**
Adversaries don't only target Windows. Crucible supports ephemeral Windows, Linux, macOS, and network OS targets. The persistent core remains consistent; the attack surface is flexible.

**6. Network Visibility at Every Boundary**
Two dedicated Zeek sensors — Arbiter and Witness — provide complete network visibility. No research traffic moves through the environment without being observed and forwarded to Nexus.

---

## Architecture Overview

Crucible is organized into two layers: a **Persistent Core** that is always running, and **Ephemeral Targets** that are spun up per research task and destroyed when complete.

### Persistent Core

| Component | Crucible Name | VLAN | Role |
|---|---|---|---|
| Elastic Stack (Elasticsearch + Kibana + Fleet) | **Nexus** | Core | Central hub for all telemetry, detection rules, and research dashboards |
| Jupyter Notebook + Elasticsearch Python client | **Nexus Console** | Core | Research interface for querying, correlating, and documenting findings |
| INetSim / FakeNet-NG | **Dark Shrine** | Core | Simulates internet-facing services. Malware calls home — Dark Shrine answers. No real internet egress. |
| REMnux-based Analysis Workstation | **Void Prism** | Analysis | Isolated environment for static and dynamic sample analysis |
| Atomic Red Team Runner | **Maelstrom** | Management | ATT&CK-aligned TTP execution engine |
| Detection Rule Library | **Khala** | N/A | Collective knowledge base of ATT&CK-mapped detection rules built from real Crucible telemetry |
| Zeek North/South Sensor | **Arbiter** | Core | Monitors all inter-VLAN traffic at the virtual router boundary |
| Zeek Detonation Sensor | **Witness** | Detonation | Captures 100% of wire traffic within the Detonation VLAN — every packet a malware sample sends or receives |

### Ephemeral Targets
Spun up per research task, torn down when complete. All targets are pre-instrumented with Elastic Agent before first boot.

| Target Type | Examples |
|---|---|
| Windows Endpoint | Windows 10/11 workstation, Windows Server 2019/2022 |
| Linux | Ubuntu Server, Debian, CentOS |
| macOS | macOS (bare metal / supported hypervisors only) |
| Network OS | pfSense, VyOS, Cisco IOSv |

---

## Network Segmentation

Crucible uses five isolated VLANs. Containment is non-negotiable — no research VM has real internet access, and no malware VM can reach your home network.

| VLAN | Name | Subnet | Key Hosts |
|---|---|---|---|
| VLAN 10 | Management | 10.10.0.0/24 | Proxmox host, Ansible controller |
| VLAN 20 | Core | 10.10.1.0/24 | Nexus, Dark Shrine, Arbiter |
| VLAN 30 | Analysis | 10.10.2.0/24 | Void Prism |
| VLAN 40 | Target | 10.10.3.0/24 | Ephemeral targets |
| VLAN 50 | Detonation | 10.10.4.0/24 | Malware VMs, Witness |

For full firewall rules, sensor placement rationale, sample intake procedures, and the Azure equivalent architecture see [docs/architecture/network-diagram.md](docs/architecture/network-diagram.md).

---

## Deployment Tiers

Crucible supports three deployment profiles. Choose based on your available resources.

### Tier 1 — Proxmox (Full Local Deployment)
**Best for:** Researchers with a dedicated homelab or server
**Requirements:** Proxmox VE 8+, 32GB+ RAM recommended, 500GB+ storage

Terraform provisions VMs via the Proxmox provider. Full environment with all persistent core components and support for multiple concurrent ephemeral targets. This is the recommended tier for malware detonation and resource-intensive analysis workflows.

### Tier 2 — Azure (Cloud Deployment)
**Best for:** Scalable, ephemeral research sessions. Spin up, research, tear down.
**Requirements:** Azure subscription, az CLI, Terraform

Provisions isolated VNets with no public internet egress from analysis or target VMs. Designed for cost-conscious use — destroy your environment when your research session ends. Well suited for adversary emulation and detection engineering workflows.

> ⚠️ **Note:** Review Microsoft Azure's Acceptable Use Policy before deploying malware samples in cloud environments. The Azure tier is best suited for adversary emulation and TTP testing. For live malware detonation, the Proxmox or Vagrant tier is recommended.

### Tier 3 — Vagrant (Minimal Local Deployment)
**Best for:** Exploration, testing, low-resource environments
**Requirements:** Vagrant, VMware Workstation or VirtualBox, 16GB+ RAM

A stripped-down single-machine profile. Runs a minimal persistent core with one ephemeral target at a time. Not intended for resource-intensive malware analysis but functional for TTP emulation and detection rule development.

---

## Research Workflows

### Workflow 1: Malware Sample Analysis
1. Intake sample to **Void Prism** (Analysis VLAN) — perform initial static analysis before detonation
2. Transfer sample to a Detonation VM via controlled intake process (never direct network path)
3. Detonate with **Witness** and Elastic Agent running — all wire traffic and endpoint telemetry captured automatically
4. **Dark Shrine** handles all outbound connection attempts — no real internet egress
5. **Arbiter** captures any cross-VLAN traffic anomalies
6. Correlate network and endpoint telemetry in **Nexus**
7. Document findings in **Nexus Console** (Jupyter + Elasticsearch Python client)
8. Export structured findings to custom Elastic index for long-term reference

### Workflow 2: TTP Emulation and Detection Development
1. Select a MITRE ATT&CK technique to research
2. Spin up an appropriate ephemeral target in the Target VLAN
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
- [ ] Void Prism — Analysis workstation provisioning (REMnux-based)
- [ ] Dark Shrine — INetSim / FakeNet-NG network isolation layer
- [ ] Arbiter — Zeek North/South sensor provisioning
- [ ] Witness — Zeek Detonation sensor provisioning
- [ ] Maelstrom — Atomic Red Team integration
- [ ] Nexus Console — Jupyter Notebook + Elasticsearch Python client
- [ ] Ephemeral Windows target template
- [ ] Ephemeral Linux target template
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

---

## Contributing

Crucible is in early development. Contributions, ideas, and feedback are welcome. Please open an issue before submitting a pull request so we can discuss the change in context of the project's direction.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

*Built for threat researchers, by threat researchers.*
