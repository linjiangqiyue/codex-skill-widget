Set-StrictMode -Version Latest

function ConvertTo-WidgetUsage {
    param([Parameter(Mandatory)][object]$Snapshot)

    if (-not $Snapshot.PSObject.Properties['Found'] -or $Snapshot.Found -ne $true) {
        return [pscustomobject]@{
            Status = 'Unavailable'
            PrimaryText = '--%'
            RemainingPercent = $null
            ResetAtLocal = $null
            LimitName = 'Codex'
            Message = if ($Snapshot.PSObject.Properties['Message']) { [string]$Snapshot.Message } else { 'No usage data' }
        }
    }

    if ($Snapshot.PSObject.Properties['IsUnlimited'] -and $Snapshot.IsUnlimited -eq $true) {
        return [pscustomobject]@{
            Status = 'Unlimited'
            PrimaryText = 'Unlimited'
            RemainingPercent = 100.0
            ResetAtLocal = $null
            LimitName = 'Codex'
            Message = ''
        }
    }

    $remaining = if ($Snapshot.PSObject.Properties['RemainingPercent']) { $Snapshot.RemainingPercent } else { $null }
    $reset = if ($Snapshot.PSObject.Properties['ResetAtLocal']) { $Snapshot.ResetAtLocal } else { $null }
    [pscustomobject]@{
        Status = 'Ok'
        PrimaryText = if ($null -ne $remaining) { '{0:N0}%' -f [Math]::Round([double]$remaining) } else { '--%' }
        RemainingPercent = $remaining
        ResetAtLocal = $reset
        LimitName = if ($Snapshot.PSObject.Properties['LimitName']) { [string]$Snapshot.LimitName } else { 'Codex' }
        Message = ''
    }
}

function Get-WidgetUsageSnapshot {
    param(
        [string]$CodexHome = (Join-Path $env:USERPROFILE '.codex'),
        [string]$UsageModulePath = (Join-Path $PSScriptRoot '..\..\codex-usage-widget\src\CodexUsage.psm1')
    )

    try {
        $resolvedModule = [IO.Path]::GetFullPath($UsageModulePath)
        if (-not (Test-Path -LiteralPath $resolvedModule)) {
            return ConvertTo-WidgetUsage -Snapshot ([pscustomobject]@{ Found=$false; Message='Usage module not found' })
        }
        Import-Module $resolvedModule -Force -ErrorAction Stop
        $snapshot = Get-CodexUsageSnapshot -CodexHome $CodexHome
        ConvertTo-WidgetUsage -Snapshot $snapshot
    }
    catch {
        ConvertTo-WidgetUsage -Snapshot ([pscustomobject]@{ Found=$false; Message=$_.Exception.Message })
    }
}

Export-ModuleMember -Function ConvertTo-WidgetUsage, Get-WidgetUsageSnapshot
