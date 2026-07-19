Describe "Repository shape" {
  It "has the main script" {
    Test-Path ".\tools\capture-conversation.ps1" | Should -BeTrue
  }

  It "has the conversation source file" {
    Test-Path ".\conversation.md" | Should -BeTrue
  }

  It "has the default config file" {
    Test-Path ".\.project-context.defaults.yml" | Should -BeTrue
  }

  It "has the docs folder" {
    Test-Path ".\docs" | Should -BeTrue
  }
}
