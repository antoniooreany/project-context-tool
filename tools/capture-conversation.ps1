param(
  [string]$InputMarkdown,

  [string]$OutputDir = ".\conversation-exports",
  [string]$RepoName = "project-context-tool",
  [string]$GitHubOwner,
  [string]$ProjectTitle = "Project Context Tool",
  [string]$ProjectDescription = "Universal project context generator for AI agents and humans.",
  [ValidateSet("public","private","internal")]
  [string]$RepositoryVisibility = "public",
  [ValidateSet("Full","LocalOnly","RepoOnly","ProjectOnly","BacklogOnly")]
  [string]$Mode = "Full",
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
  param([Parameter(Mandatory)][string]$Message)
  Write-Host "[INFO] $Message"
}

function Write-Warn {
  param([Parameter(Mandatory)][string]$Message)
  Write-Warning "[WARN] $Message"
}

function Write-Fail {
  param([Parameter(Mandatory)][string]$Message)
  throw "[ERROR] $Message"
}

function Ensure-Directory {
  param([Parameter(Mandatory)][string]$Path)
  if (-not (Test-Path $Path)) {
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
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

function Invoke-NativeCommand {
  param(
    [Parameter(Mandatory)][string]$FilePath,
    [string[]]$Arguments = @(),
    [switch]$AllowFailure,
    [switch]$CaptureOutput
  )

  $global:LASTEXITCODE = 0

  if ($CaptureOutput) {
    $output = & $FilePath @Arguments 2>&1
    $exitCode = $global:LASTEXITCODE
    if (-not $AllowFailure -and $exitCode -ne 0) {
      $text = ($output | Out-String).Trim()
      throw "Command failed ($exitCode): $FilePath $($Arguments -join ' ')`n$text"
    }
    return @{
      ExitCode = $exitCode
      Output   = ($output | Out-String)
    }
  } else {
    & $FilePath @Arguments
    $exitCode = $global:LASTEXITCODE
    if (-not $AllowFailure -and $exitCode -ne 0) {
      throw "Command failed ($exitCode): $FilePath $($Arguments -join ' ')"
    }
    return @{
      ExitCode = $exitCode
      Output   = $null
    }
  }
}

function Get-ModeFlags {
  param([Parameter(Mandatory)][string]$Mode)

  switch ($Mode) {
    "LocalOnly" {
      return @{
        CreateRepository    = $false
        CreateGitHubProject = $false
        CreateBacklog       = $false
      }
    }
    "RepoOnly" {
      return @{
        CreateRepository    = $true
        CreateGitHubProject = $false
        CreateBacklog       = $false
      }
    }
    "ProjectOnly" {
      return @{
        CreateRepository    = $false
        CreateGitHubProject = $true
        CreateBacklog       = $false
      }
    }
    "BacklogOnly" {
      return @{
        CreateRepository    = $false
        CreateGitHubProject = $false
        CreateBacklog       = $true
      }
    }
    default {
      return @{
        CreateRepository    = $true
        CreateGitHubProject = $true
        CreateBacklog       = $true
      }
    }
  }
}

function New-SlidesMarkdownFromConversation {
  param([Parameter(Mandatory)][string]$SourceMarkdown)
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
  param([Parameter(Mandatory)][string]$ProjectName)
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
  Invoke-NativeCommand -FilePath "pandoc" -Arguments @($MarkdownPath, "-o", $DocxPath) | Out-Null

  Write-Info "Pandoc detected. Exporting PDF."
  Invoke-NativeCommand -FilePath "pandoc" -Arguments @($MarkdownPath, "-o", $PdfPath) | Out-Null

  Write-Info "Pandoc detected. Exporting PPTX from slide-formatted markdown."
  Invoke-NativeCommand -FilePath "pandoc" -Arguments @($SlidesMarkdownPath, "-o", $PptxPath) | Out-Null
}

function Ensure-GitHubCli {
  if (-not (Test-Command "gh")) {
    Write-Fail "GitHub CLI was not found."
  }
}

function Ensure-Git {
  if (-not (Test-Command "git")) {
    Write-Fail "Git was not found."
  }
}

function Ensure-GitHubOwner {
  param([string]$Owner)

  if ($Owner) { return $Owner }

  Ensure-GitHubCli
  $result = Invoke-NativeCommand -FilePath "gh" -Arguments @("api", "user", "--jq", ".login") -CaptureOutput
  $resolved = $result.Output.Trim()

  if ([string]::IsNullOrWhiteSpace($resolved)) {
    Write-Fail "GitHub owner could not be resolved from gh authentication."
  }

  return $resolved
}

function Ensure-GitRepository {
  Ensure-Git

  if (-not (Test-Path ".git")) {
    Write-Info "Initializing local git repository."
    Invoke-NativeCommand -FilePath "git" -Arguments @("init") | Out-Null
    Invoke-NativeCommand -FilePath "git" -Arguments @("branch", "-M", "main") | Out-Null
  }

  $result = Invoke-NativeCommand -FilePath "git" -Arguments @("rev-parse", "--show-toplevel") -CaptureOutput
  $root = $result.Output.Trim()

  if ([string]::IsNullOrWhiteSpace($root)) {
    Write-Fail "Local git repository root could not be determined."
  }

  Write-Info "Local git repository detected at $root"
  return $root
}

function Ensure-GitIgnore {
  $path = ".gitignore"
  $lines = @(
    ".DS_Store"
    "Thumbs.db"
    ".idea/"
    ".vscode/"
    "conversation-exports/"
    "*.tmp"
    "*.bak"
  )

  if (-not (Test-Path $path)) {
    Save-TextFile -Path $path -Content ($lines -join [Environment]::NewLine)
    Write-Info ".gitignore created."
    return
  }

  $existing = Get-Content -Path $path -Encoding UTF8
  $changed = $false

  foreach ($line in $lines) {
    if ($existing -notcontains $line) {
      Add-Content -Path $path -Value $line -Encoding UTF8
      $changed = $true
    }
  }

  if ($changed) {
    Write-Info ".gitignore updated."
  } else {
    Write-Info ".gitignore already contains required rules."
  }
}

function Ensure-GitAttributes {
  $path = ".gitattributes"
  $content = @"
* text=auto
*.ps1 text eol=lf
*.psm1 text eol=lf
*.md text eol=lf
*.txt text eol=lf
*.json text eol=lf
*.yml text eol=lf
*.yaml text eol=lf
*.xml text eol=lf
*.ts text eol=lf
*.js text eol=lf
*.sh text eol=lf
*.bat text eol=crlf
*.cmd text eol=crlf
"@

  if (-not (Test-Path $path)) {
    Save-TextFile -Path $path -Content $content
    Write-Info ".gitattributes created."
    return
  }

  $existing = Get-Content -Path $path -Raw -Encoding UTF8
  if ($existing -ne $content) {
    Save-TextFile -Path $path -Content $content
    Write-Info ".gitattributes updated."
  } else {
    Write-Info ".gitattributes already up to date."
  }
}

function Test-GitHubRepoExists {
  param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$RepoName
  )

  Ensure-GitHubCli
  $fullRepo = "$Owner/$RepoName"
  $result = Invoke-NativeCommand -FilePath "gh" -Arguments @("repo", "view", $fullRepo) -AllowFailure -CaptureOutput
  return ($result.ExitCode -eq 0)
}

function Ensure-OriginRemote {
  param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$RepoName
  )

  $remoteUrl = "https://github.com/$Owner/$RepoName.git"
  $check = Invoke-NativeCommand -FilePath "git" -Arguments @("remote", "get-url", "origin") -AllowFailure -CaptureOutput

  if ($check.ExitCode -eq 0) {
    $existing = $check.Output.Trim()
    if ($existing -ne $remoteUrl) {
      Write-Info "Updating origin remote URL."
      Invoke-NativeCommand -FilePath "git" -Arguments @("remote", "set-url", "origin", $remoteUrl) | Out-Null
    } else {
      Write-Info "Origin remote already configured."
    }
  } else {
    Write-Info "Adding origin remote."
    Invoke-NativeCommand -FilePath "git" -Arguments @("remote", "add", "origin", $remoteUrl) | Out-Null
  }
}

function Ensure-GitHubRepo {
  param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][string]$RepoName,
    [Parameter(Mandatory)][string]$Visibility
  )

  Ensure-GitHubCli
  Ensure-GitRepository | Out-Null

  $fullRepo = "$Owner/$RepoName"

  if (Test-GitHubRepoExists -Owner $Owner -RepoName $RepoName) {
    Write-Info "GitHub repository already exists: $fullRepo"
  } else {
    Write-Info "Creating GitHub repository: $fullRepo"
    Invoke-NativeCommand -FilePath "gh" -Arguments @("repo", "create", $fullRepo, "--$Visibility", "--source", ".", "--remote", "origin") | Out-Null
  }

  Ensure-OriginRemote -Owner $Owner -RepoName $RepoName
  return $fullRepo
}

function Push-RepositoryFilesOnly {
  Ensure-GitRepository | Out-Null
  Ensure-GitIgnore
  Ensure-GitAttributes

  Write-Info "Refreshing git index for ignored generated files."
  Invoke-NativeCommand -FilePath "git" -Arguments @("rm", "-r", "--cached", "--ignore-unmatch", "conversation-exports") -AllowFailure | Out-Null

  Write-Info "Staging repository files only."
  Invoke-NativeCommand -FilePath "git" -Arguments @("add", ".gitignore", ".gitattributes", "README.md", ".project-context.defaults.yml", "conversation.md", "docs", "tools") -AllowFailure | Out-Null
  Invoke-NativeCommand -FilePath "git" -Arguments @("add", ".") | Out-Null

  $status = Invoke-NativeCommand -FilePath "git" -Arguments @("status", "--porcelain") -CaptureOutput
  $lines = @($status.Output -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
  $filtered = @($lines | Where-Object { $_ -notmatch "conversation-exports/" })

  if ($filtered.Count -gt 0) {
    Write-Info "Creating commit for repository changes."
    $commitResult = Invoke-NativeCommand -FilePath "git" -Arguments @("commit", "-m", "Update project artifacts and automation scripts") -AllowFailure -CaptureOutput
    if ($commitResult.ExitCode -ne 0) {
      Write-Warn "Commit was not created automatically. Continuing."
    }
  } else {
    Write-Info "No repository file changes detected for commit."
  }

  Write-Info "Pushing current branch to origin."
  Invoke-NativeCommand -FilePath "git" -Arguments @("push", "-u", "origin", "HEAD") | Out-Null
}

function Ensure-ProjectScopes {
  Ensure-GitHubCli

  $status = Invoke-NativeCommand -FilePath "gh" -Arguments @("auth", "status") -CaptureOutput
  $text = $status.Output

  $hasProject = $text -match "project"
  $hasReadProject = $text -match "read:project"

  if (-not $hasProject -or -not $hasReadProject) {
    Write-Fail "GitHub CLI token is missing required scopes for projects. Run: gh auth refresh -h github.com -s project,read:project"
  }

  Write-Info "GitHub CLI project scopes are available."
}

function Ensure-GitHubLabel {
  param(
    [Parameter(Mandatory)][string]$Repo,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Color,
    [Parameter(Mandatory)][string]$Description
  )

  $result = Invoke-NativeCommand -FilePath "gh" -Arguments @("label", "create", $Name, "--repo", $Repo, "--color", $Color, "--description", $Description) -AllowFailure -CaptureOutput
  $output = $result.Output

  if ($result.ExitCode -eq 0) {
    Write-Info "Label created: $Name"
    return
  }

  if ($output -match "already exists") {
    Write-Info "Label already exists: $Name"
    return
  }

  Write-Fail "Failed to create label '$Name'. $output"
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

  $list = Invoke-NativeCommand -FilePath "gh" -Arguments @("issue", "list", "--repo", $Repo, "--search", $Title, "--json", "title", "--jq", ".[].title") -AllowFailure -CaptureOutput
  if ($list.ExitCode -eq 0) {
    $titles = @($list.Output -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($titles -contains $Title) {
      Write-Info "Issue already exists: $Title"
      return
    }
  }

  $labelArgs = @()
  foreach ($label in $Labels) {
    $labelArgs += @("--label", $label)
  }

  $create = Invoke-NativeCommand -FilePath "gh" -Arguments (@("issue", "create", "--repo", $Repo, "--title", $Title, "--body", $Body) + $labelArgs) -AllowFailure -CaptureOutput
  if ($create.ExitCode -ne 0) {
    Write-Fail "Failed to create issue '$Title'. $($create.Output)"
  }

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

  Ensure-ProjectScopes

  $create = Invoke-NativeCommand -FilePath "gh" -Arguments @("project", "create", "--owner", $Owner, "--title", $Title) -AllowFailure -CaptureOutput
  if ($create.ExitCode -ne 0) {
    if ($create.Output -match "already exists") {
      Write-Info "GitHub Project already exists: $Title"
    } else {
      Write-Fail "Failed to create GitHub Project '$Title'. $($create.Output)"
    }
  } else {
    Write-Info "GitHub Project created: $Title"
  }

  $list = Invoke-NativeCommand -FilePath "gh" -Arguments @("project", "list", "--owner", $Owner, "--format", "json") -CaptureOutput
  $projects = $list.Output | ConvertFrom-Json
  $project = $projects.projects | Where-Object { $_.title -eq $Title } | Select-Object -First 1

  if (-not $project) {
    Write-Fail "GitHub Project '$Title' could not be located after creation."
  }

  Write-Info "GitHub Project located: $Title (#$($project.number))"
  return $project.number
}

function Add-IssuesToProject {
  param(
    [Parameter(Mandatory)][string]$Owner,
    [Parameter(Mandatory)][int]$ProjectNumber,
    [Parameter(Mandatory)][string]$Repo
  )

  Ensure-ProjectScopes

  $issuesResult = Invoke-NativeCommand -FilePath "gh" -Arguments @("issue", "list", "--repo", $Repo, "--limit", "100", "--json", "number,title") -CaptureOutput
  $issues = $issuesResult.Output | ConvertFrom-Json

  foreach ($issue in $issues) {
    $url = "https://github.com/$Repo/issues/$($issue.number)"
    $add = Invoke-NativeCommand -FilePath "gh" -Arguments @("project", "item-add", $ProjectNumber, "--owner", $Owner, "--url", $url) -AllowFailure -CaptureOutput
    if ($add.ExitCode -eq 0) {
      Write-Info "Added issue to project: #$($issue.number) $($issue.title)"
    } elseif ($add.Output -match "already exists") {
      Write-Info "Issue already linked to project: #$($issue.number)"
    } else {
      Write-Fail "Failed to add issue #$($issue.number) to project. $($add.Output)"
    }
  }
}

if ($Mode -in @("Full", "LocalOnly")) {
  if ([string]::IsNullOrWhiteSpace($InputMarkdown) -or -not (Test-Path $InputMarkdown)) {
    Write-Fail "Input markdown file '$InputMarkdown' was not found."
  }
}

$flags = Get-ModeFlags -Mode $Mode
$CreateRepository = $flags.CreateRepository
$CreateGitHubProject = $flags.CreateGitHubProject
$CreateBacklog = $flags.CreateBacklog

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

Ensure-GitIgnore
Ensure-GitAttributes

$logLines = @()
$logLines += "[INFO] Conversation capture started at $(Get-Date -Format o)"
$logLines += "[INFO] Mode: $Mode"
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
  $repoFullName = Ensure-GitHubRepo -Owner $GitHubOwner -RepoName $RepoName -Visibility $RepositoryVisibility
  if ($Force) {
    Push-RepositoryFilesOnly
  }
  Create-GitHubLabels -Repo $repoFullName
}

if ($CreateBacklog) {
  if (-not $repoFullName) {
    Write-Fail "Backlog creation requires a resolved GitHub repository."
  }
  if (-not (Test-GitHubRepoExists -Owner $GitHubOwner -RepoName $RepoName)) {
    Write-Fail "Backlog creation requires an existing GitHub repository."
  }
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
