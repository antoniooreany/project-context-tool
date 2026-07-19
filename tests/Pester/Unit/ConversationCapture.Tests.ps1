Describe "Conversation capture script" {
  It "contains a Mode parameter" {
    $content = Get-Content ".\tools\capture-conversation.ps1" -Raw
    $content | Should -Match 'Mode'
  }

  It "contains LocalOnly mode support" {
    $content = Get-Content ".\tools\capture-conversation.ps1" -Raw
    $content | Should -Match 'LocalOnly'
  }

  It "contains RepoOnly mode support" {
    $content = Get-Content ".\tools\capture-conversation.ps1" -Raw
    $content | Should -Match 'RepoOnly'
  }

  It "contains ProjectOnly mode support" {
    $content = Get-Content ".\tools\capture-conversation.ps1" -Raw
    $content | Should -Match 'ProjectOnly'
  }

  It "contains BacklogOnly mode support" {
    $content = Get-Content ".\tools\capture-conversation.ps1" -Raw
    $content | Should -Match 'BacklogOnly'
  }
}
