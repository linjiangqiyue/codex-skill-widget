$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$testOutput=Join-Path $env:TEMP ('codex-skill-release-test-'+[guid]::NewGuid().ToString('N'))
try{
    & (Join-Path $root 'scripts\Build-Release.ps1') -Version '0.0.0-test' -OutputRoot $testOutput|Out-Null
    $windowsZip=Join-Path $testOutput 'CodexSkillHelper-Windows-v0.0.0-test.zip'
    $macZip=Join-Path $testOutput 'CodexSkillHelper-macOS-Web-v0.0.0-test.zip'
    if(-not(Test-Path -LiteralPath $windowsZip)){throw 'Windows 发布包未生成'}
    if(-not(Test-Path -LiteralPath $macZip)){throw 'Mac 网页轻版发布包未生成'}
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $windows=[IO.Compression.ZipFile]::OpenRead($windowsZip)
    try{$names=@($windows.Entries.FullName|ForEach-Object{$_ -replace '\\','/'});foreach($required in @('双击启动-Codex助手.bat','Start-CodexSkillWidget.ps1','src/SkillCatalog.psm1')){if(-not($names -contains $required)){throw "Windows 包缺少 $required"}}}finally{$windows.Dispose()}
    $extractDir=Join-Path $testOutput 'extracted-windows';[IO.Compression.ZipFile]::ExtractToDirectory($windowsZip,$extractDir)
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File (Join-Path $extractDir 'Start-CodexSkillWidget.ps1') -ValidateOnly|Out-Null
    if($LASTEXITCODE -ne 0){throw 'Windows 发布包解压后无法通过启动验证'}
    $mac=[IO.Compression.ZipFile]::OpenRead($macZip)
    try{
        $names=@($mac.Entries.FullName);if(-not($names -contains '打开-Codex助手.webloc')){throw 'Mac 包缺少双击网页入口'}
        $entry=$mac.Entries|Where-Object FullName -eq '打开-Codex助手.webloc'|Select-Object -First 1
        $reader=New-Object IO.StreamReader($entry.Open());try{$shortcut=$reader.ReadToEnd()}finally{$reader.Dispose()}
        if($shortcut -notmatch 'https://linjiangqiyue.github.io/codex-skill-widget/'){throw 'Mac 网页入口地址错误'}
    }finally{$mac.Dispose()}
    Write-Output 'PASS: release package behavior tests'
}finally{
    if(Test-Path -LiteralPath $testOutput){Remove-Item -LiteralPath $testOutput -Recurse -Force}
}
