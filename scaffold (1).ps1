# Crucible - Repository Scaffold Script
# Run this from the root of your cloned crucible repo
# Usage: .\scaffold.ps1

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
    "ansible/roles/nexus",
    "ansible/roles/void-prism",
    "ansible/roles/maelstrom",
    "ansible/roles/dark-shrine",
    "ansible/roles/nexus-console",
    "ansible/roles/elastic-agent",
    "ansible/roles/common",
    "ansible/playbooks/targets",
    "ansible/inventory",
    "targets/windows",
    "targets/linux",
    "targets/macos",
    "targets/network",
    "khala/rules",
    "ai/mcp-servers/nexus-mcp",
    "ai/mcp-servers/khala-mcp",
    "ai/mcp-servers/attack-mcp",
    "ai/prompts",
    ".github/ISSUE_TEMPLATE"
)

foreach ($dir in $directories) {
    # Create the directory if it doesn't exist
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    # Create .gitkeep placeholder
    $gitkeep = "$dir/.gitkeep"
    if (-not (Test-Path $gitkeep)) {
        New-Item -ItemType File -Path $gitkeep -Force | Out-Null
    }
    Write-Host "Created: $dir" -ForegroundColor Cyan
}

# Create top level placeholder files if they don't exist
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
Write-Host "Run the following to push to GitHub:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  git add ." -ForegroundColor White
Write-Host "  git commit -m 'scaffold: initialize repository structure'" -ForegroundColor White
Write-Host "  git push" -ForegroundColor White
