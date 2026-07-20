param(
    [string]$ConfigPath = (Join-Path $PSScriptRoot '..\marketing\config.json'),
    [string]$OutputPath,
    [string]$Repository,
    [string]$Token = $env:GITHUB_TOKEN
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\src\MarketingAutomation.psm1') -Force
$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $Repository) { $Repository = [string]$config.repository }
if (-not $Token -and (Get-Command gh -ErrorAction SilentlyContinue)) {
    $Token = (& gh auth token 2>$null)
}
if (-not $OutputPath) {
    $outputDir = Join-Path $PSScriptRoot '..\marketing-output'
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    $OutputPath = Join-Path $outputDir ('growth-brief-{0}.md' -f (Get-Date -Format 'yyyy-MM-dd'))
}
$metrics = Get-GitHubGrowthMetrics -Repository $Repository -Token $Token
$brief = New-MarketingBrief -Config $config -Metrics $metrics
$parent = Split-Path -Parent $OutputPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
[IO.File]::WriteAllText($OutputPath,$brief,(New-Object Text.UTF8Encoding($false)))
Write-Output (Resolve-Path -LiteralPath $OutputPath).Path
