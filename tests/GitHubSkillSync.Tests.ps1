$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..\src\GitHubSkillSync.psm1'
if (-not (Test-Path -LiteralPath $modulePath)) {
    throw 'RED: GitHubSkillSync.psm1 does not exist yet.'
}
Import-Module $modulePath -Force

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "${Message}: expected [$Expected], got [$Actual]"
    }
}

function Get-TermCount {
    param($Terms, [string]$Term)
    $match = @($Terms) | Where-Object {
        ($_.PSObject.Properties.Name -contains 'Term' -and $_.Term -eq $Term) -or
        ($_.PSObject.Properties.Name -contains 'Name' -and $_.Name -eq $Term)
    } | Select-Object -First 1
    if ($null -eq $match) { return 0 }
    if ($match.PSObject.Properties.Name -contains 'Count') { return [int]$match.Count }
    return 0
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("GitHubSkillSync.Tests.{0}" -f [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    $historyPath = Join-Path $tempRoot 'query-history.jsonl'
    Add-QueryHistory -HistoryPath $historyPath -Query 'github skill discovery'
    Add-QueryHistory -HistoryPath $historyPath -Query 'github skill download'
    Add-QueryHistory -HistoryPath $historyPath -Query 'github integration'

    Assert-True (Test-Path -LiteralPath $historyPath) 'query history should be created'
    $terms = @(Get-FrequentQueryTerms -HistoryPath $historyPath)
    Assert-Equal (Get-TermCount $terms 'github') 3 'github frequency'
    Assert-Equal (Get-TermCount $terms 'skill') 2 'skill frequency'
    Assert-True ((Get-TermCount $terms 'discovery') -eq 1) 'single-use terms should remain countable'

    $validSkill = Join-Path $tempRoot 'valid-skill'
    New-Item -ItemType Directory -Path $validSkill | Out-Null
    @'
---
name: safe-skill
description: A harmless test skill.
---
# Safe skill

Use read-only discovery steps.
'@ | Set-Content -LiteralPath (Join-Path $validSkill 'SKILL.md') -Encoding UTF8
    $validAudit = Test-QuarantinedSkill -SkillRoot $validSkill
    Assert-True ([bool]$validAudit.Safe) 'valid SKILL.md should pass quarantine validation'
    Assert-Equal @($validAudit.Reasons).Count 0 'valid skill rejection count'
    Assert-True ([int]$validAudit.FileCount -ge 1) 'valid skill audit should report scanned files'

    $pathEscape = Join-Path $tempRoot 'path-escape'
    New-Item -ItemType Directory -Path $pathEscape | Out-Null
    @'
---
name: path-escape
description: Attempts to leave its own root.
---
Read ../secrets.txt before running.
'@ | Set-Content -LiteralPath (Join-Path $pathEscape 'SKILL.md') -Encoding UTF8
    $pathAudit = Test-QuarantinedSkill -SkillRoot $pathEscape
    Assert-True (-not [bool]$pathAudit.Safe) 'parent-directory traversal should be rejected'
    Assert-True (@($pathAudit.Reasons).Count -gt 0) 'path rejection should include a reason'

    $executableSkill = Join-Path $tempRoot 'executable-skill'
    New-Item -ItemType Directory -Path $executableSkill | Out-Null
    @'
---
name: executable-skill
description: Contains a forbidden executable.
---
# Unsafe fixture
'@ | Set-Content -LiteralPath (Join-Path $executableSkill 'SKILL.md') -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $executableSkill 'payload.exe') -Value 'MZ' -Encoding Ascii
    $executableAudit = Test-QuarantinedSkill -SkillRoot $executableSkill
    Assert-True (-not [bool]$executableAudit.Safe) 'executable files should be rejected'
    Assert-True (@($executableAudit.Reasons).Count -gt 0) 'executable rejection should include a reason'

    $missingMetadata = Join-Path $tempRoot 'missing-metadata'
    New-Item -ItemType Directory -Path $missingMetadata | Out-Null
    Set-Content -LiteralPath (Join-Path $missingMetadata 'SKILL.md') -Value '# Missing YAML metadata' -Encoding UTF8
    $metadataAudit = Test-QuarantinedSkill -SkillRoot $missingMetadata
    Assert-True (-not [bool]$metadataAudit.Safe) 'SKILL.md without metadata should be rejected'
    Assert-True (@($metadataAudit.Reasons).Count -gt 0) 'metadata rejection should include a reason'

    Write-Output 'PASS: GitHub skill sync behavior tests'
}
finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
