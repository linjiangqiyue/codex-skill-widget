param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\docs\assets\codex-skill-helper-demo-30s.mp4')
)

$ErrorActionPreference='Stop'
if(-not(Get-Command ffmpeg -ErrorAction SilentlyContinue)){throw '需要先安装 ffmpeg'}
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$font='C:\Windows\Fonts\msyh.ttc'
if(-not(Test-Path -LiteralPath $font)){$font='C:\Windows\Fonts\msyhbd.ttc'}
if(-not(Test-Path -LiteralPath $font)){throw '找不到 Microsoft YaHei 中文字体'}
$temp=Join-Path $env:TEMP ('codex-skill-demo-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $temp|Out-Null
try{
    $scenes=@(
        @{Image='docs\assets\demo-frames\01-ui-problem.png';Text='我知道页面不对　但我不知道该怎么说';Seconds=7},
        @{Image='docs\assets\demo-frames\01-ui-problem.png';Text='用普通中文描述问题　自动获得专业检查要求';Seconds=8},
        @{Image='docs\assets\demo-frames\02-managed-task.png';Text='任务边界、暂停条件和验收标准一次整理好';Seconds=8},
        @{Image='docs\assets\widget-standard.png';Text='295 项能力都有中文解释　开源免费下载';Seconds=7}
    )
    $segmentFiles=@()
    for($i=0;$i -lt $scenes.Count;$i++){
        $scene=$scenes[$i];$source=Join-Path $root $scene.Image;$segment=Join-Path $temp ('segment-{0:00}.mp4' -f $i)
        $escapedFont=($font -replace '\\','/') -replace ':','\:'
        $filter="scale=480:-1:flags=lanczos,pad=1280:720:(ow-iw)/2:112:color=0x111012,drawtext=fontfile='$escapedFont':text='$($scene.Text)':fontcolor=white:fontsize=34:x=(w-text_w)/2:y=42"
        & ffmpeg -hide_banner -loglevel error -y -loop 1 -i $source -t $scene.Seconds -vf $filter -r 30 -c:v libx264 -pix_fmt yuv420p -movflags +faststart $segment
        if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $segment)){throw "视频片段生成失败：$i"}
        $segmentFiles+=$segment
    }
    $list=Join-Path $temp 'concat.txt'
    $lines=$segmentFiles|ForEach-Object{"file '$($_ -replace "'","''")'"}
    [IO.File]::WriteAllLines($list,$lines,(New-Object Text.UTF8Encoding($false)))
    $parent=Split-Path -Parent ([IO.Path]::GetFullPath($OutputPath));New-Item -ItemType Directory -Force -Path $parent|Out-Null
    & ffmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i $list -c copy -movflags +faststart $OutputPath
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $OutputPath)){throw '演示视频合成失败'}
    $duration=& ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $OutputPath
    [pscustomobject]@{Path=[IO.Path]::GetFullPath($OutputPath);DurationSeconds=[Math]::Round([double]$duration,1);Bytes=(Get-Item $OutputPath).Length}
}finally{
    $tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath());$resolvedTemp=[IO.Path]::GetFullPath($temp)
    if($resolvedTemp.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -and ([IO.Path]::GetFileName($resolvedTemp) -like 'codex-skill-demo-*') -and (Test-Path -LiteralPath $resolvedTemp)){
        Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    }
}
