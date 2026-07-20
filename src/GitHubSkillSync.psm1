Set-StrictMode -Version Latest

function Get-QueryTerms([string]$Query) {
    $stop = @('这个','那个','然后','可以','一个','一些','根据','进行','需要','帮我','自动','怎么','什么','如果','比如','或者','再去','整理','整合')
    $text = $Query.ToLowerInvariant()
    foreach ($word in $stop) { $text = $text.Replace($word, ' ') }
    @([regex]::Matches($text, '[a-z][a-z0-9_-]{1,}|[\p{IsCJKUnifiedIdeographs}]{2,8}') |
        ForEach-Object Value | Where-Object { $_.Length -ge 2 } | Select-Object -Unique)
}

function Add-QueryHistory {
    param([Parameter(Mandatory)][string]$HistoryPath, [Parameter(Mandatory)][string]$Query)
    $items = @()
    if (Test-Path -LiteralPath $HistoryPath) {
        try { $parsed = Get-Content -LiteralPath $HistoryPath -Raw -Encoding UTF8 | ConvertFrom-Json; foreach ($entry in $parsed) { $items += $entry } } catch { $items = @() }
    }
    $items += [pscustomobject]@{ Query=$Query.Trim(); At=[datetime]::UtcNow.ToString('o') }
    $parent = Split-Path -Parent $HistoryPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    @($items | Select-Object -Last 200) | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $HistoryPath -Encoding UTF8
}

function Get-FrequentQueryTerms {
    param([Parameter(Mandatory)][string]$HistoryPath, [int]$Top=6)
    if (-not (Test-Path -LiteralPath $HistoryPath)) { return @() }
    $items = @()
    try { $parsed = Get-Content -LiteralPath $HistoryPath -Raw -Encoding UTF8 | ConvertFrom-Json; foreach ($entry in $parsed) { $items += $entry } } catch { return @() }
    @($items | Where-Object { $null -ne $_.PSObject.Properties['Query'] } | ForEach-Object { Get-QueryTerms ([string]$_.Query) } |
        Group-Object | Sort-Object Count,Name -Descending | Select-Object -First $Top |
        ForEach-Object { [pscustomobject]@{ Term=$_.Name; Count=$_.Count } })
}

function Invoke-GitHubApi([string]$Uri) {
    $headers = @{ 'User-Agent'='Codex-Skill-Widget'; 'Accept'='application/vnd.github+json' }
    if ($env:GITHUB_TOKEN) { $headers.Authorization = "Bearer $($env:GITHUB_TOKEN)" }
    elseif ($env:GH_TOKEN) { $headers.Authorization = "Bearer $($env:GH_TOKEN)" }
    Invoke-RestMethod -Uri $Uri -Headers $headers -Method Get -TimeoutSec 20
}

function Find-GitHubSkillCandidates {
    param([string[]]$Terms, [int]$MaxRepositories=4, [int]$MaxSkills=8)
    $termText = (@($Terms | Select-Object -First 4) -join ' ')
    $query = [uri]::EscapeDataString(('codex skill {0} in:name,description,readme' -f $termText).Trim())
    $search = Invoke-GitHubApi "https://api.github.com/search/repositories?q=$query&sort=stars&order=desc&per_page=$MaxRepositories"
    $found = New-Object System.Collections.Generic.List[object]
    foreach ($repo in @($search.items)) {
        if ($found.Count -ge $MaxSkills) { break }
        try {
            $tree = Invoke-GitHubApi "https://api.github.com/repos/$($repo.full_name)/git/trees/$($repo.default_branch)?recursive=1"
            foreach ($entry in @($tree.tree | Where-Object { $_.type -eq 'blob' -and $_.path -match '(^|/)SKILL\.md$' })) {
                if ($found.Count -ge $MaxSkills) { break }
                $skillPath = ([string]$entry.path -replace '(^|/)SKILL\.md$','')
                if ([string]::IsNullOrWhiteSpace($skillPath)) { $skillPath='.' }
                $found.Add([pscustomobject]@{
                    Repository=[string]$repo.full_name; Ref=[string]$repo.default_branch
                    SkillPath=$skillPath
                    Stars=[int]$repo.stargazers_count; UpdatedAt=[string]$repo.updated_at
                    HtmlUrl=[string]$repo.html_url
                })
            }
        } catch { continue }
    }
    $found.ToArray()
}

function Test-QuarantinedSkill {
    param([Parameter(Mandatory)][string]$SkillRoot)
    $reasons = New-Object System.Collections.Generic.List[string]
    $skillFile = Join-Path $SkillRoot 'SKILL.md'
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) { $reasons.Add('缺少 SKILL.md') }
    else {
        $text = Get-Content -LiteralPath $skillFile -Raw -Encoding UTF8
        if ($text -notmatch '(?ms)^---\s*.*?^name:\s*.+?^description:\s*.+?^---') { $reasons.Add('SKILL.md 元数据不完整') }
        if ($text -match '(?i)(ignore\s+(all|previous)\s+instructions|读取|上传|发送).{0,40}(token|密钥|credential|密码)') { $reasons.Add('发现疑似提示注入或凭据收集指令') }
        if ($text -match '(?m)(^|[\s"''])\.\.[\\/]') { $reasons.Add('发现父目录路径访问') }
    }
    $files = @(Get-ChildItem -LiteralPath $SkillRoot -Recurse -File -Force -ErrorAction SilentlyContinue)
    if ($files.Count -gt 250) { $reasons.Add('文件数量超过 250') }
    if (($files | Measure-Object Length -Sum).Sum -gt 20MB) { $reasons.Add('总体积超过 20MB') }
    $blocked = @('.exe','.dll','.msi','.scr','.com','.jar','.sys')
    if ($files | Where-Object { $blocked -contains $_.Extension.ToLowerInvariant() }) { $reasons.Add('包含可执行或二进制文件') }
    [pscustomobject]@{ Safe=($reasons.Count -eq 0); Reasons=@($reasons); FileCount=$files.Count }
}

function Expand-GitHubCandidateToQuarantine {
    param([Parameter(Mandatory)]$Candidate, [Parameter(Mandatory)][string]$QuarantineRoot)
    $safeRepo = $Candidate.Repository -replace '[^a-zA-Z0-9_.-]','_'
    $stage = Join-Path $QuarantineRoot ("{0}_{1}" -f $safeRepo,([guid]::NewGuid().ToString('N')))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    $zip = Join-Path $stage 'repo.zip'; $expanded = Join-Path $stage 'expanded'
    Invoke-WebRequest -Uri "https://api.github.com/repos/$($Candidate.Repository)/zipball/$($Candidate.Ref)" -Headers @{'User-Agent'='Codex-Skill-Widget'} -OutFile $zip -TimeoutSec 30
    Expand-Archive -LiteralPath $zip -DestinationPath $expanded -Force
    $repoRoot = Get-ChildItem -LiteralPath $expanded -Directory | Select-Object -First 1
    $skillRoot = if ([string]::IsNullOrWhiteSpace([string]$Candidate.SkillPath)) { $repoRoot.FullName } else { Join-Path $repoRoot.FullName $Candidate.SkillPath }
    [pscustomobject]@{ Stage=$stage; SkillRoot=$skillRoot; Audit=(Test-QuarantinedSkill -SkillRoot $skillRoot) }
}

function Install-GitHubSkillCandidate {
    param([Parameter(Mandatory)]$Candidate, [Parameter(Mandatory)][string]$CodexHome)
    $installer = Join-Path $CodexHome 'skills\.system\skill-installer\scripts\install-skill-from-github.py'
    if (-not (Test-Path -LiteralPath $installer)) { throw '找不到 Codex skill-installer。' }
    $args = @($installer,'--repo',$Candidate.Repository,'--ref',$Candidate.Ref,'--path',$Candidate.SkillPath,'--dest',(Join-Path $CodexHome 'skills'))
    & python @args
    if ($LASTEXITCODE -ne 0) { throw "skill-installer 退出码 $LASTEXITCODE" }
}

Export-ModuleMember -Function Add-QueryHistory,Get-FrequentQueryTerms,Find-GitHubSkillCandidates,Test-QuarantinedSkill,Expand-GitHubCandidateToQuarantine,Install-GitHubSkillCandidate
