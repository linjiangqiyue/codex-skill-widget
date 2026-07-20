$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testOutput=Join-Path $env:TEMP ('codex-skill-release-test-'+[guid]::NewGuid().ToString('N'))
try{
    & (Join-Path $root 'scripts\Build-Release.ps1') -Version '0.0.0-test' -OutputRoot $testOutput|Out-Null
    $windowsZip=Join-Path $testOutput 'CodexSkillHelper-Windows-v0.0.0-test.zip'
    if(-not(Test-Path -LiteralPath $windowsZip)){throw 'Windows 发布包未生成'}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $windows=[IO.Compression.ZipFile]::OpenRead($windowsZip)
    try{$names=@($windows.Entries.FullName|ForEach-Object{$_ -replace '\\','/'});foreach($required in @('双击启动-Codex助手.bat','Start-CodexSkillWidget.ps1','src/SkillCatalog.psm1')){if(-not($names -contains $required)){throw "Windows 包缺少 $required"}}}finally{$windows.Dispose()}
    $extractDir=Join-Path $testOutput 'extracted-windows';[IO.Compression.ZipFile]::ExtractToDirectory($windowsZip,$extractDir)
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File (Join-Path $extractDir 'Start-CodexSkillWidget.ps1') -ValidateOnly|Out-Null
    if($LASTEXITCODE -ne 0){throw 'Windows 发布包解压后无法通过启动验证'}
    Write-Output 'PASS: release package behavior tests'
}finally{
    if(Test-Path -LiteralPath $testOutput){Remove-Item -LiteralPath $testOutput -Recurse -Force}
}
