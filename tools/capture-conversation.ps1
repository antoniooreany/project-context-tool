param(
  [Parameter(Mandatory)]
  [string]$InputMarkdown,

  [string]$OutputDir = ".\conversation-exports",
  [string]$RepoName = "project-context-tool",
  [string]$GitHubOwner,
  [string]$ProjectTitle = "Project Context Tool",
  [string]$ProjectDescription = "Universal project context generator for AI agents and humans.",
  [ValidateSet("public","private","internal")]
  [string]$RepositoryVisibility = "public",
  [switch]$CreateRepository,
  [switch]$CreateGitHubProject,
  [switch]$CreateBacklog,
  [switch]$SkipPandoc,
  [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-Command {
  param([Parameter(Mandatory)][string]$Name)
  return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Write-Info {
  param([string]$Message)
  Write-Host "[INFO] $Message"
}

function Write-Warn {
  param([string]$Message)
  Write-Warning "[WARN] $Message"
}

function Ensure-Directory {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path $Path)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Save-TextFile {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Content
  )
  $parent = Split-Path -Parent $Path
  if ($parent) { Ensure-Directory -Path $parent }
  Set-Content -Path $Path -Value $Content -Encoding UTF8
}

function New-SlidesMarkdownFromConversation {
  param(
    [Parameter(Mandatory)][string]$SourceMarkdown
  )

  $raw = Get-Content -Path $SourceMarkdown -Raw -Encoding UTF8

  return @"
% Project Context Tool Conversation Capture
% Automated Export
% $(Get-Date -Format "yyyy-MM-dd")

# Conversation Capture

- Source: $SourceMarkdown
- Generated: $(Get-Date -Format "o")
- Purpose: Preserve planning, decisions, and repository setup.

---

# Main Topics

- Universal project context generation
- Raw-first architecture
- Detection and confidence
- Refresh policy
- Extensible contracts and plugins
- English-only repository policy

---

# Outputs

- Markdown transcript
- Plain log
- DOCX export
- PDF export
- PPTX export
- Mermaid mind map
- GitHub repository automation
- GitHub Project backlog

---

# Transcript Snapshot

$($raw -replace '\r?\n', "`n")
"@
}

function New-MindMapContent {
  param(
    [Parameter(Mandatory)][string]$ProjectName
  )

  return @"
mindmap
  root(($ProjectName))
    Architecture
      Raw Model
      Detection Pipeline
      Confidence Model
      Plugin Registry
      Contract Registry
      Builder Pipeline
    Outputs
      RAW_STRUCTURE.md
      LLM_CONTEXT.md
      DETECTION_HELP.md
      FULL_TEXT_INDEX.md
      raw-model.json
    Refresh Policy
      If Changed
      If Stale
      On Question
      Smart
      On Commit
      On Push
      On Pull Request
      On Post Merge
    Extensibility
      Analyzers
      Detectors
      Builders
      Fixtures
      Triggers
      Serializers
      Hooks
      Profiles
    Governance
      English Only Policy
      Labels
      Issue Templates
      Backlog Structure
"@
}

function Invoke-PandocExport {
  param(
    [Parameter(Mandatory)][string]$MarkdownPath,
    [Parameter(Mandatory)][string]$DocxPath,
    [Parameter(Mandatory)][string]$PdfPath,
    [Parameter(Mandatory)][string]$PptxPath,
    [Parameter(Mandatory)][string]$SlidesMarkdownPath
  )

  if (-not (Test-Command "pandoc")) {
    Write-Warn "Pandoc was not found. DOCX, PDF, and PPTX exports were skipped."
    return
  }

  Write-Info "Pandoc detected. Exporting DOCX."
  & pandoc $MarkdownPath -o $DocxPath

  Write-Info "Pandoc detected. Exporting PDF."
  & pandoc $MarkdownPath -o $PdfPath

  Write-Info "Pandoc detected. Exporting PPTX from slide-formatted markdown."
  & pandoc $SlidesMarkdownPath -o $PptxPath
}

function Ensure-GitHubOwner {
  param([string]$Owner)

  if ($Owner) {
    return $Owner
  }

  if (-not (Test-Command "gh")) {
    throw "GitHub CLI was not found and GitHubOwner was not provided."
  }

  return (& gh api user --jq '.login').Trim()
}

function Invoke-GitHubRepositorySetup {
  param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$RepoName,
    [Parameter(Mandatory)][string]$Visibility,
    [switch]$Force
  )

  if (-not (Test-Command "gh")) {
    Write-Warn "GitHub CLI was not found. Repository setup was skipped."
    return
  }

  $fullRepo = "$Owner/$RepoName"

  try {
    & gh repo view $fullRepo | Out-Null
    Write-Info "Repository already exists: $fullRepo"
  } catch {
    Write-Info "Creating repository: $fullRepo"
    & gh repo create $fullRepo --$Visibility --source . --remote origin
  }

  try {
    git rev-parse --is-inside-work-tree | Out-Null
    Write-Info "Local git repository detected."
  } catch {
    Write-Info "Initializing local git repository."
    git init | Out-Null
  }

  try {
    git remote get-url origin | Out-Null
  } catch {
    Write-Info "Adding origin remote."
    git remote add origin "https://github.com/$fullRepo.git"
  }

  if ($Force) {
    Write-Info "Pushing current branch to origin."
    git add . | Out-Null
    try { git commit -m "Initialize project context tool" | Out-Null } catch { }
    git push -u origin HEAD
  }
}

function Ensure-GitHubLabel {
  param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Color,
    [Parameter(Mandatory)][string]$Description
  )

  try {
    & gh label create $Name --repo $Repo --color $Color --description $Description | Out-Null
    Write-Info "Label created: $Name"
  } catch {
    Write-Info "Label already exists or could not be created: $Name"
  }
}

function Create-GitHubLabels {
  param([Parameter(Mandatory)][string]$Repo)

  Ensure-GitHubLabel -Repo $Repo -Name "type:feature"    -Color "1f6feb" -Description "Feature work"
  Ensure-GitHubLabel -Repo $Repo -Name "type:bug"        -Color "d73a4a" -Description "Bug fix"
  Ensure-GitHubLabel -Repo $Repo -Name "type:docs"       -Color "0e8a16" -Description "Documentation work"
  Ensure-GitHubLabel -Repo $Repo -Name "type:infra"      -Color "5319e7" -Description "Infrastructure work"
  Ensure-GitHubLabel -Repo $Repo -Name "type:research"   -Color "fbca04" -Description "Research and analysis"
  Ensure-GitHubLabel -Repo $Repo -Name "area:core"       -Color "0052cc" -Description "Core system"
  Ensure-GitHubLabel -Repo $Repo -Name "area:detection"  -Color "0366d6" -Description "Detection pipeline"
  Ensure-GitHubLabel -Repo $Repo -Name "area:plugins"    -Color "6f42c1" -Description "Plugin system"
  Ensure-GitHubLabel -Repo $Repo -Name "area:outputs"    -Color "1d76db" -Description "Generated artifacts"
  Ensure-GitHubLabel -Repo $Repo -Name "area:docs"       -Color "0e8a16" -Description "Documentation and templates"
  Ensure-GitHubLabel -Repo $Repo -Name "priority:high"   -Color "b60205" -Description "High priority"
  Ensure-GitHubLabel -Repo $Repo -Name "priority:medium" -Color "fbca04" -Description "Medium priority"
  Ensure-GitHubLabel -Repo $Repo -Name "priority:low"    -Color "cfd3d7" -Description "Low priority"
}

function New-IssueIfNeeded {
  param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Title,
    [Parameter(Mandatory)][string]$Body,
    [Parameter(Mandatory)][string[]]$Labels
  )

  try {
    $existing = & gh issue list --repo $Repo --search $Title --json title --jq '.[].title'
    if ($existing -and ($existing -split "`n") -contains $Title) {
      Write-Info "Issue already exists: $Title"
      return
    }
  } catch { }

  $labelArgs = @()
  foreach ($label in $Labels) {
    $labelArgs += @("--label", $label)
  }

  & gh issue create --repo $Repo --title $Title --body $Body @labelArgs | Out-Null
  Write-Info "Issue created: $Title"
}

function Create-BacklogIssues {
  param([Parameter(Mandatory)][string]$Repo)

  New-IssueIfNeeded -Repo $Repo -Title "Implement raw model scanner" -Body "Build the raw-first repository scanner and raw-model.json generator." -Labels @("type:feature","area:core","priority:high")
  New-IssueIfNeeded -Repo $Repo -Title "Implement detection pipeline and overall confidence" -Body "Create detectors, candidate scoring, and overall detection confidence reporting." -Labels @("type:feature","area:detection","priority:high")
  New-IssueIfNeeded -Repo $Repo -Title "Implement plugin and contract registries" -Body "Add extensible registries for contracts, analyzers, detectors, builders, triggers, fixtures, serializers, hooks, and profiles." -Labels @("type:feature","area:plugins","priority:high")
  New-IssueIfNeeded -Repo $Repo -Title "Implement LLM context and raw structure builders" -Body "Generate RAW_STRUCTURE.md, LLM_CONTEXT.md, and related output artifacts from the raw model." -Labels @("type:feature","area:outputs","priority:high")
  New-IssueIfNeeded -Repo $Repo -Title "Write repository documentation and policies" -Body "Add architecture docs, config schema, output format docs, and the English-only policy." -Labels @("type:docs","area:docs","priority:medium")
}

function Create-GitHubProjectAndCaptureId {
  param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$Title
  )

  if (-not (Test-Command "gh")) {
    Write-Warn "GitHub CLI was not found. Project creation was skipped."
    return $null
  }

  try {
    & gh project create --owner $Owner --title $Title | Out-Null
    Write-Info "GitHub Project creation command executed."
  } catch {
    Write-Warn "GitHub Project could not be created automatically."
  }

  try {
    $projectsJson = & gh project list --owner $Owner --format json
    $projects = $projectsJson | ConvertFrom-Json
    $project = $projects.projects | Where-Object { $_.title -eq $Title } | Select-Object -First 1
    if ($project) {
      Write-Info "GitHub Project located: $Title (#$($project.number))"
      return $project.number
    }
  } catch {
    Write-Warn "GitHub Project lookup failed."
  }

  return $null
}

function Add-IssuesToProject {
  param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][int]$ProjectNumber,
    [Parameter(Mandatory)][string]$Repo
  )

  try {
    $issues = & gh issue list --repo $Repo --limit 100 --json number,title | ConvertFrom-Json
    foreach ($issue in $issues) {
      try {
        & gh project item-add $ProjectNumber --owner $Owner --url "https://github.com/$Repo/issues/$($issue.number)" | Out-Null
        Write-Info "Added issue to project: #$($issue.number) $($issue.title)"
      } catch {
        Write-Info "Issue already added or could not be added: #$($issue.number)"
      }
    }
  } catch {
    Write-Warn "Issues could not be added to the project."
  }
}

if (-not (Test-Path $InputMarkdown)) {
  throw "Input markdown file '$InputMarkdown' was not found."
}

Ensure-Directory -Path $OutputDir

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$baseName = "conversation-$timestamp"

$mdPath       = Join-Path $OutputDir "$baseName.md"
$docxPath     = Join-Path $OutputDir "$baseName.docx"
$pdfPath      = Join-Path $OutputDir "$baseName.pdf"
$pptxPath     = Join-Path $OutputDir "$baseName.pptx"
$logPath      = Join-Path $OutputDir "$baseName.log"
$mindMapPath  = Join-Path $OutputDir "$baseName.mmd"
$slidesMdPath = Join-Path $OutputDir "$baseName.slides.md"

Copy-Item $InputMarkdown $mdPath -Force
Write-Info "Markdown transcript copied to $mdPath"

$slidesMarkdown = New-SlidesMarkdownFromConversation -SourceMarkdown $mdPath
Save-TextFile -Path $slidesMdPath -Content $slidesMarkdown
Write-Info "Slide-formatted markdown created at $slidesMdPath"

$mindMap = New-MindMapContent -ProjectName "Project Context Tool"
Save-TextFile -Path $mindMapPath -Content $mindMap
Write-Info "Mermaid mind map created at $mindMapPath"

if (-not $SkipPandoc) {
  Invoke-PandocExport -MarkdownPath $mdPath -DocxPath $docxPath -PdfPath $pdfPath -PptxPath $pptxPath -SlidesMarkdownPath $slidesMdPath
}

$logLines = @()
$logLines += "[INFO] Conversation capture started at $(Get-Date -Format o)"
$logLines += "[INFO] Input markdown: $InputMarkdown"
$logLines += "[INFO] Markdown export: $mdPath"
$logLines += "[INFO] Slide markdown export: $slidesMdPath"
$logLines += "[INFO] Mermaid mind map export: $mindMapPath"
$logLines += "[INFO] DOCX export target: $docxPath"
$logLines += "[INFO] PDF export target: $pdfPath"
$logLines += "[INFO] PPTX export target: $pptxPath"

$repoFullName = $null
$projectNumber = $null

if ($CreateRepository -or $CreateGitHubProject -or $CreateBacklog) {
  $GitHubOwner = Ensure-GitHubOwner -Owner $GitHubOwner
  $repoFullName = "$GitHubOwner/$RepoName"
  $logLines += "[INFO] GitHub owner resolved to: $GitHubOwner"
  $logLines += "[INFO] Repository target: $repoFullName"
}

if ($CreateRepository) {
  Invoke-GitHubRepositorySetup -Owner $GitHubOwner -RepoName $RepoName -Visibility $RepositoryVisibility -Force:$Force
  Create-GitHubLabels -Repo $repoFullName
}

if ($CreateBacklog) {
  Create-BacklogIssues -Repo $repoFullName
}

if ($CreateGitHubProject) {
  $projectNumber = Create-GitHubProjectAndCaptureId -Owner $GitHubOwner -Title $ProjectTitle
  if ($projectNumber -and $CreateBacklog) {
    Add-IssuesToProject -Owner $GitHubOwner -ProjectNumber $projectNumber -Repo $repoFullName
  }
}

$logLines += "[INFO] Repository creation enabled: $CreateRepository"
$logLines += "[INFO] Project creation enabled: $CreateGitHubProject"
$logLines += "[INFO] Backlog creation enabled: $CreateBacklog"
if ($projectNumber) {
  $logLines += "[INFO] GitHub Project number: $projectNumber"
}
$logLines += "[INFO] Conversation capture completed at $(Get-Date -Format o)"

Save-TextFile -Path $logPath -Content ($logLines -join [Environment]::NewLine)
Write-Info "Plain log created at $logPath"
Write-Info "Conversation capture completed."
