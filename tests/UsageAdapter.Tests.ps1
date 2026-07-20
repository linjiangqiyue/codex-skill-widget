$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..\src\UsageAdapter.psm1'
if (-not (Test-Path -LiteralPath $modulePath)) {
    throw 'RED: UsageAdapter.psm1 does not exist yet.'
}

Import-Module $modulePath -Force

function Assert-Equal {
    param($Actual, $Expected, [string]$Message)
    if ($Actual -ne $Expected) {
        throw "${Message}: expected [$Expected], got [$Actual]"
    }
}

$reset = [datetime]'2026-07-27T12:00:00'
$ok = ConvertTo-WidgetUsage -Snapshot ([pscustomobject]@{
    Found = $true
    RemainingPercent = 95
    ResetAtLocal = $reset
    LimitName = 'Codex'
    IsUnlimited = $false
})
Assert-Equal $ok.Status 'Ok' 'available snapshot status'
Assert-Equal $ok.PrimaryText '95%' 'available snapshot percent'
Assert-Equal $ok.ResetAtLocal $reset 'available snapshot reset time'

$missing = ConvertTo-WidgetUsage -Snapshot ([pscustomobject]@{ Found = $false; Message = 'offline' })
Assert-Equal $missing.Status 'Unavailable' 'missing snapshot status'
Assert-Equal $missing.PrimaryText '--%' 'missing snapshot placeholder'

$unlimited = ConvertTo-WidgetUsage -Snapshot ([pscustomobject]@{ Found = $true; IsUnlimited = $true })
Assert-Equal $unlimited.Status 'Unlimited' 'unlimited status'
Assert-Equal $unlimited.PrimaryText 'Unlimited' 'unlimited label'

Write-Output 'PASS: UsageAdapter behavior tests'
