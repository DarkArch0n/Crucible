# Crucible - Repository Scaffold Script
# Run this from the root of your cloned crucible repo
# Usage: .\scaffold.ps1
#
# Three-VLAN architecture:
#   VLAN 10 - Management  (Proxmox, Ansible)
#   VLAN 20 - Core        (Nexus, Dark Shrine, Arbiter)
#   VLAN 30 - Detonation  (Witness, ephemeral analysis + malware VM pairs)

$directories = @(
    "docs/architecture",
    "docs/workflows",
    "docs/components",
    "terraform/modules/proxmox",
    "terraform/modules/azure",
    "terraform/modules/vagrant",
    "terraform/profiles/full",
    "terraform/profiles/cloud",
    "terraform/profiles/minimal",
    "ansible/roles/common-linux",
    "ansible/roles/common-windows",
    "ansible/roles/nexus",
    "ansible/roles/maelstrom",
    "ansible/roles/dark-shrine",
    "ansible/roles/nexus-console",
    "ansible/roles/elastic-agent-linux",
    "ansible/roles/elastic-agent-windows",
    "ansible/roles/arbiter",
    "ansible/roles/witness",
    "ansible/playbooks/targets",
    "ansible/inventory",
    "targets/win-analysis",
    "targets/lin-analysis",
    "targets/win-malware",
    "targets/lin-malware",
    "targets/macos",
    "targets/network-os",
    "khala/rules",
    "ai/mcp-servers/nexus-mcp",
    "ai/mcp-servers/khala-mcp",
    "ai/mcp-servers/attack-mcp",
    "ai/prompts",
    ".github/ISSUE_TEMPLATE"
)

foreach ($dir in $directories) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $gitkeep = "$dir/.gitkeep"
    if (-not (Test-Path $gitkeep)) {
        New-Item -ItemType File -Path $gitkeep -Force | Out-Null
    }
    Write-Host "Created: $dir" -ForegroundColor Cyan
}

$topLevelFiles = @(
    "LICENSE",
    ".gitignore",
    "khala/index.md",
    "ai/README.md",
    ".github/PULL_REQUEST_TEMPLATE.md",
    ".github/ISSUE_TEMPLATE/bug_report.md",
    ".github/ISSUE_TEMPLATE/research_contribution.md"
)

foreach ($file in $topLevelFiles) {
    if (-not (Test-Path $file)) {
        New-Item -ItemType File -Path $file -Force | Out-Null
        Write-Host "Created: $file" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Crucible scaffold complete." -ForegroundColor Magenta
Write-Host ""
Write-Host "Architecture: Three VLANs" -ForegroundColor Yellow
Write-Host "  VLAN 10 - Management  : Proxmox, Ansible" -ForegroundColor White
Write-Host "  VLAN 20 - Core        : Nexus, Dark Shrine, Arbiter" -ForegroundColor White
Write-Host "  VLAN 30 - Detonation  : Witness + ephemeral VM pairs" -ForegroundColor White
Write-Host ""
Write-Host "  Analysis VMs are ephemeral (targets/win-analysis, targets/lin-analysis)" -ForegroundColor White
Write-Host "  No persistent void-prism role - analysis lives in the Detonation VLAN" -ForegroundColor White
Write-Host ""
Write-Host "Push to GitHub:" -ForegroundColor Yellow
Write-Host "  git add ." -ForegroundColor White
Write-Host "  git commit -m 'scaffold: update to three-VLAN architecture'" -ForegroundColor White
Write-Host "  git push" -ForegroundColor White
