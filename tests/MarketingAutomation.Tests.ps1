$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\src\MarketingAutomation.psm1') -Force

function Assert-Contains([string]$Text,[string]$Expected,[string]$Message) {
    if (-not $Text.Contains($Expected)) { throw "$Message，缺少：$Expected" }
}

$tracked = ConvertTo-TrackedUrl -BaseUrl 'https://example.com/project' -Source '小红书' -Campaign 'weekly launch' -Content 'ui-check'
Assert-Contains $tracked 'utm_source=%E5%B0%8F%E7%BA%A2%E4%B9%A6' '来源参数应进行 URL 编码'
Assert-Contains $tracked 'utm_campaign=weekly%20launch' '活动参数应进行 URL 编码'

$config = [pscustomobject]@{
    repositoryUrl='https://github.com/example/project'
    painPoints=@([pscustomobject]@{
        slug='ui-check';title='测试标题';searchQuery='测试搜索词';hook='测试用户痛点'
        videoTitle='测试视频标题';socialTitle='测试社交标题'
    })
}
$metrics = [pscustomobject]@{
    Stars=3;Forks=2;OpenIssues=1;ReleaseDownloads=9
    Views14d=20;UniqueVisitors14d=8;Clones14d=5;UniqueCloners14d=4
}
$brief = New-MarketingBrief -Config $config -Metrics $metrics -GeneratedAt ([datetime]'2026-07-21')
Assert-Contains $brief '测试标题' '简报应包含轮换主题'
Assert-Contains $brief '用户可能会搜：“测试搜索词”' '简报应正确展开搜索词'
Assert-Contains $brief '| GitHub Stars | 3 |' '简报应包含 GitHub 指标'
Assert-Contains $brief 'utm_source=zhihu' '知乎草稿应使用独立追踪链接'
Assert-Contains $brief 'utm_source=bilibili' 'B 站草稿应使用独立追踪链接'
Assert-Contains $brief '系统不会自动登录或代发社交平台' '简报必须声明人工确认边界'

Write-Output 'PASS: Marketing automation behavior tests'
