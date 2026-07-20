Set-StrictMode -Version Latest

function ConvertTo-TrackedUrl {
    param(
        [Parameter(Mandatory)][string]$BaseUrl,
        [Parameter(Mandatory)][string]$Source,
        [string]$Campaign = 'organic-launch',
        [string]$Content = 'weekly-brief'
    )
    $separator = if ($BaseUrl.Contains('?')) { '&' } else { '?' }
    $encode = { param([string]$Value) [Uri]::EscapeDataString($Value) }
    $BaseUrl + $separator + 'utm_source=' + (&$encode $Source) +
        '&utm_medium=community&utm_campaign=' + (&$encode $Campaign) +
        '&utm_content=' + (&$encode $Content)
}

function Invoke-GitHubJson {
    param([string]$Url,[hashtable]$Headers)
    try { Invoke-RestMethod -Uri $Url -Headers $Headers -UseBasicParsing -ErrorAction Stop } catch { $null }
}

function Get-GitHubGrowthMetrics {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [string]$Token = $env:GITHUB_TOKEN
    )
    $headers = @{Accept='application/vnd.github+json';'User-Agent'='codex-skill-widget-growth-loop'}
    if ($Token) { $headers.Authorization = "Bearer $Token" }
    $api = "https://api.github.com/repos/$Repository"
    $repo = Invoke-GitHubJson -Url $api -Headers $headers
    if ($null -eq $repo) { throw "无法读取 GitHub 仓库：$Repository" }
    $releaseResponse = Invoke-GitHubJson -Url "$api/releases?per_page=100" -Headers $headers
    $releases = if ($null -eq $releaseResponse) { @() } else { @($releaseResponse) }
    $downloads = 0
    foreach ($release in $releases) {
        if ($null -ne $release -and $release.PSObject.Properties['assets']) {
            foreach ($asset in @($release.assets)) { $downloads += [int]$asset.download_count }
        }
    }
    $views = Invoke-GitHubJson -Url "$api/traffic/views" -Headers $headers
    $clones = Invoke-GitHubJson -Url "$api/traffic/clones" -Headers $headers
    [pscustomobject]@{
        Stars = [int]$repo.stargazers_count
        Forks = [int]$repo.forks_count
        OpenIssues = [int]$repo.open_issues_count
        ReleaseDownloads = $downloads
        Views14d = if ($views) { [int]$views.count } else { $null }
        UniqueVisitors14d = if ($views) { [int]$views.uniques } else { $null }
        Clones14d = if ($clones) { [int]$clones.count } else { $null }
        UniqueCloners14d = if ($clones) { [int]$clones.uniques } else { $null }
        CollectedAt = [datetime]::UtcNow
    }
}

function Format-MetricValue {
    param($Value)
    if ($null -eq $Value) { return '暂不可用' }
    return [string]$Value
}

function New-MarketingBrief {
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)]$Metrics,
        [datetime]$GeneratedAt = [datetime]::Now
    )
    $painPoints = @($Config.painPoints)
    if (-not $painPoints.Count) { throw '推广配置至少需要一个用户痛点' }
    $angle = $painPoints[$GeneratedAt.DayOfYear % $painPoints.Count]
    $repoUrl = [string]$Config.repositoryUrl
    $dateText = $GeneratedAt.ToString('yyyy-MM-dd')
    $zhihu = ConvertTo-TrackedUrl $repoUrl 'zhihu' 'organic-weekly' $angle.slug
    $bilibili = ConvertTo-TrackedUrl $repoUrl 'bilibili' 'organic-weekly' $angle.slug
    $xiaohongshu = ConvertTo-TrackedUrl $repoUrl 'xiaohongshu' 'organic-weekly' $angle.slug
    $v2ex = ConvertTo-TrackedUrl $repoUrl 'v2ex' 'organic-weekly' $angle.slug
    $views = Format-MetricValue $Metrics.Views14d
    $visitors = Format-MetricValue $Metrics.UniqueVisitors14d
    $clones = Format-MetricValue $Metrics.Clones14d
    $cloners = Format-MetricValue $Metrics.UniqueCloners14d
    @"
# 推广闭环周报 · $dateText

> 这是一份自动生成的发布草稿。请由墨老板确认事实、语气和平台规则后再发布；系统不会自动登录或代发社交平台。

## 本周信号

| 指标 | 当前值 | 怎么理解 |
|---|---:|---|
| GitHub Stars | $($Metrics.Stars) | 愿意持续关注的人 |
| Forks | $($Metrics.Forks) | 愿意继续改造的人 |
| 近 14 天浏览 | $views（独立访客 $visitors） | 内容有没有把人带到仓库 |
| 近 14 天克隆 | $clones（独立克隆者 $cloners） | 有多少人真正尝试拿走项目 |
| Release 下载 | $($Metrics.ReleaseDownloads) | 一键下载入口的真实使用量 |
| 开放 Issue/PR | $($Metrics.OpenIssues) | 用户反馈与协作信号，含 PR |

## 本周只讲一个问题

**$($angle.title)**

- 用户可能会搜：“$($angle.searchQuery)”
- 开场：$($angle.hook)
- 证明方式：录制一次真实输入 → 生成中文提示词 → 复制给 Codex 的完整过程。
- 唯一行动：邀请读者下载并告诉我们哪一步仍然看不懂。

## 知乎回答草稿

### 标题

$($angle.title)

### 正文骨架

我自己长期遇到同一个问题：$($angle.hook)

真正困难的往往不是“让 AI 再写一遍”，而是把模糊的不满意说成具体、可执行、能验收的要求。建议先写清楚三件事：哪里偏离、什么不能改、怎样才算完成。

因为我不会写代码，却经常需要和 Codex 一起做产品，所以做了一个开源的中文桌面小组件。它会解释英文 Skills，把口语整理成带边界和验收条件的提示词。项目仍然很早期，欢迎直接指出问题。

项目：$zhihu

## B 站短视频脚本

**标题：** $($angle.videoTitle)

1. 0–5 秒：展示出错结果，说“$($angle.hook)”
2. 5–15 秒：在小组件输入同一句普通话。
3. 15–30 秒：展示中文能力解释和生成的验收提示词。
4. 30–45 秒：复制给 Codex，说明它不会替用户偷偷做重要决定。
5. 结尾：这是墨老板的第一个开源项目，下载地址：$bilibili

## 小红书草稿

**标题：** $($angle.socialTitle)

我不会写代码，但我知道自己想做什么。

$($angle.hook)

后来我给自己做了一个很小的 Windows 组件：不用先学会几百个英文 Skill，只要用中文说出哪里难受，它就帮我整理成 Codex 能执行、我也能验收的话。

它还很早期，但已经开源。如果你也有过“知道不对，却说不清楚”的时刻，希望你来试试，也欢迎直接告诉我哪里不好用。

$xiaohongshu

#Codex #AI编程 #开源项目 #独立开发 #不会代码

## V2EX / 掘金草稿

**标题：** 第一个开源项目：给普通中文用户做了一个 Codex Skill 桌面助手

项目来自我自己的高频痛点：$($angle.hook)

目前用 PowerShell + WPF 实现，包含中文 Skill 映射、任务模式、额度读取、GitHub 候选隔离审核和三档窗口尺寸。这次更希望获得两类反馈：真实 Windows 环境能否顺利运行，以及中文解释是否真的降低了理解成本。

仓库：$v2ex

## 发布前人工检查

- [ ] 内容描述与当前版本一致，没有夸大功能
- [ ] 截图或视频中没有个人路径、令牌和私人项目
- [ ] 每个平台只发适合它的版本，不批量复制刷屏
- [ ] 链接使用对应平台的追踪参数
- [ ] 发布后记录真实评论、下载问题和失败步骤

## 下周复盘

不要只看曝光和 Star。优先回答：

1. 哪个平台带来了真实克隆或 Release 下载？
2. 新用户是否成功启动？卡在下载、PowerShell 还是产品理解？
3. 哪条用户原话值得成为下一周的内容，而不是继续猜关键词？
4. 是否有人愿意第二次使用、反馈或推荐给别人？
"@
}

Export-ModuleMember -Function ConvertTo-TrackedUrl,Get-GitHubGrowthMetrics,New-MarketingBrief
