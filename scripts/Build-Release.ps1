param(
    [string]$Version = '0.1.0',
    [string]$OutputRoot = (Join-Path $PSScriptRoot '..\dist')
)

$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$output=[IO.Path]::GetFullPath($OutputRoot)
$projectDist=[IO.Path]::GetFullPath((Join-Path $projectRoot 'dist'))
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$safeProjectTarget=$output.Equals($projectDist,[StringComparison]::OrdinalIgnoreCase) -or $output.StartsWith($projectDist+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)
$safeTestTarget=$output.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -and ([IO.Path]::GetFileName($output) -like 'codex-skill-release-test-*')
if(-not($safeProjectTarget -or $safeTestTarget)){throw "拒绝清理不安全的输出目录：$output"}
if(Test-Path -LiteralPath $output){Remove-Item -LiteralPath $output -Recurse -Force}
New-Item -ItemType Directory -Force -Path $output|Out-Null

$windowsDir=Join-Path $output "CodexSkillHelper-Windows-v$Version"
New-Item -ItemType Directory -Force -Path (Join-Path $windowsDir 'src')|Out-Null
foreach($file in @('Start-CodexSkillWidget.ps1','双击启动-Codex助手.bat','QUICKSTART-WINDOWS.md','LICENSE')){
    Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination $windowsDir
}
foreach($file in @('SkillCatalog.psm1','UsageAdapter.psm1','GitHubSkillSync.psm1')){
    Copy-Item -LiteralPath (Join-Path $projectRoot "src\$file") -Destination (Join-Path $windowsDir 'src')
}
$windowsZip=Join-Path $output "CodexSkillHelper-Windows-v$Version.zip"
Compress-Archive -Path (Join-Path $windowsDir '*') -DestinationPath $windowsZip -CompressionLevel Optimal

$macDir=Join-Path $output "CodexSkillHelper-macOS-Web-v$Version"
New-Item -ItemType Directory -Force -Path $macDir|Out-Null
Copy-Item -LiteralPath (Join-Path $projectRoot 'macos-web\打开-Codex助手.webloc') -Destination $macDir
Copy-Item -LiteralPath (Join-Path $projectRoot 'macos-web\README-MAC.md') -Destination $macDir
Copy-Item -LiteralPath (Join-Path $projectRoot 'LICENSE') -Destination $macDir
$macZip=Join-Path $output "CodexSkillHelper-macOS-Web-v$Version.zip"
Compress-Archive -Path (Join-Path $macDir '*') -DestinationPath $macZip -CompressionLevel Optimal

$result=@(
    [pscustomobject]@{Platform='Windows';Path=$windowsZip;Bytes=(Get-Item $windowsZip).Length},
    [pscustomobject]@{Platform='macOS Web';Path=$macZip;Bytes=(Get-Item $macZip).Length}
)
$result|Format-Table -AutoSize
$result
