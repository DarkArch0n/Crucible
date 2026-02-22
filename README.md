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

---

## Architecture Overview

Crucible is organized into two layers: a **Persistent Core** that is always running, and **Ephemeral Targets** that are spun up per research task and destroyed when complete.

### Persistent Core

| Component | Crucible Name | Role |
|---|---|---|
| Elastic Stack (Elasticsearch + Kibana + Fleet) | **Nexus** | Central hub for all telemetry, detection rules, and research dashboards. The Elasticsearch Python client exposes Nexus data to Jupyter for analysis workflows. |
| Malware Analysis Workstation (REMnux-based) | **Void Prism** | Isolated analysis environment for static and dynamic sample analysis. Dangerous things enter here — controlled, contained, observed. |
| Adversary Emulation Runner (Atomic Red Team) | **Maelstrom** | ATT&CK-aligned TTP execution engine. Freezes a moment in adversary behavior so you can study what it leaves behind. |
| Detection Rule Library | **Khala** | The collective knowledge base. ATT&CK-mapped detection rules built from real telemetry observed in Crucible research sessions. |
| Network Isolation Layer (INetSim / FakeNet-NG) | **Dark Shrine** | Simulates internet-facing services without real external connectivity. Malware calls home — Dark Shrine answers. |
| Research Interface (Jupyter Notebook) | **Nexus Console** | Jupyter Notebook server with Elasticsearch Python client pre-configured. Query, correlate, and document research findings in one place. |

### Ephemeral Targets
Spun up per research task, torn down when complete. All targets are pre-instrumented with Elastic Agent before first boot.

| Target Type | Examples |
|---|---|
| Windows Endpoint | Windows 10/11 workstation, Windows Server 2019/2022 |
| Linux | Ubuntu Server, Debian, CentOS |
| macOS | macOS (bare metal / supported hypervisors only) |
| Network OS | pfSense, VyOS, Cisco IOSv |

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
1. Intake sample to **Void Prism** (isolated analysis workstation)
2. Perform static analysis — strings, PE headers, YARA, Ghidra
3. Detonate in an ephemeral target VM with Elastic Agent pre-deployed
4. Dynamic artifacts (process creation, network connections, file system changes, registry modifications) forward automatically to **Nexus**
5. **Dark Shrine** handles any outbound network calls from the sample — no real internet egress
6. Correlate static and dynamic findings in **Nexus Console** (Jupyter + Elasticsearch Python client)
7. Export structured findings to a custom Elastic index for long-term reference

### Workflow 2: TTP Emulation and Detection Development
1. Select a MITRE ATT&CK technique to research
2. Spin up an appropriate ephemeral target
3. Execute the technique via **Maelstrom** (Atomic Red Team) or manually
4. Observe telemetry in **Nexus** — what data sources fired, what fields populated
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
- [ ] Maelstrom — Atomic Red Team integration
- [ ] Nexus Console — Jupyter Notebook + Elasticsearch Python client
- [ ] Ephemeral Windows target template
- [ ] Ephemeral Linux target template
- [ ] Khala — Initial ATT&CK-aligned detection rule library
- [ ] Ghidra to Elastic artifact export pipeline
- [ ] macOS target support
- [ ] Network OS target support
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

---

## Contributing

Crucible is in early development. Contributions, ideas, and feedback are welcome. Please open an issue before submitting a pull request so we can discuss the change in context of the project's direction.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

*Built for threat researchers, by threat researchers.*
