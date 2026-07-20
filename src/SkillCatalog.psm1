Set-StrictMode -Version Latest

function Get-SkillMetadata {
    param([Parameter(Mandatory)][string]$SkillFile)

    $lines = Get-Content -LiteralPath $SkillFile -Encoding UTF8 -ErrorAction Stop
    if ($lines.Count -lt 4 -or $lines[0].Trim() -ne '---') { return $null }

    $name = $null
    $description = $null
    for ($i = 1; $i -lt [Math]::Min($lines.Count, 80); $i++) {
        if ($lines[$i].Trim() -eq '---') { break }
        if ($lines[$i] -match '^name:\s*["'']?(.*?)["'']?\s*$') { $name = $matches[1].Trim() }
        if ($lines[$i] -match '^description:\s*["'']?(.*?)["'']?\s*$') { $description = $matches[1].Trim() }
    }

    if ([string]::IsNullOrWhiteSpace($name) -or [string]::IsNullOrWhiteSpace($description)) { return $null }
    [pscustomobject]@{ Name = $name; Description = $description; Path = $SkillFile }
}

function Get-SkillCategory {
    param([string]$Name, [string]$Description)
    $nameText = $Name.ToLowerInvariant()
    $nameRules = @(
        @{ Name = '产品经理'; Terms = @('product','prd','roadmap','user-story','persona','priorit','market') },
        @{ Name = '架构开发'; Terms = @('architecture','api','database','backend','monorepo','migration','refactor','codebase') },
        @{ Name = '测试调试'; Terms = @('test','debug','review','verification','quality') },
        @{ Name = '界面设计'; Terms = @('design','ui','ux','frontend','visual','image-to-code','styling','brand') }
    )
    foreach ($rule in $nameRules) {
        foreach ($term in $rule.Terms) { if ($nameText.Contains($term)) { return $rule.Name } }
    }
    $text = ($Name + ' ' + $Description).ToLowerInvariant()
    $rules = @(
        @{ Name = '产品经理'; Terms = @('product', 'prd', 'roadmap', 'user stor', 'persona', 'priorit', 'discovery', 'stakeholder', 'market') },
        @{ Name = '测试调试'; Terms = @('test', 'debug', 'review', 'verification', 'quality', 'playwright', 'pytest') },
        @{ Name = '架构开发'; Terms = @('architecture', 'api', 'database', 'backend', 'monorepo', 'migration', 'refactor', 'codebase') },
        @{ Name = '界面设计'; Terms = @('design', 'ui', 'ux', 'frontend', 'visual', 'image-to-code', 'styling', 'brand') },
        @{ Name = '数据分析'; Terms = @('analytics', 'metric', 'data', 'dashboard', 'kpi', 'experiment') },
        @{ Name = '安全逆向'; Terms = @('reverse', 'binary', 'pentest', 'security', 'exploit', 'apk', 'firmware') },
        @{ Name = '文档内容'; Terms = @('document', 'pdf', 'presentation', 'writing', 'report', 'content') }
    )
    foreach ($rule in $rules) {
        foreach ($term in $rule.Terms) { if ($text.Contains($term)) { return $rule.Name } }
    }
    return '通用工具'
}

function Get-ChineseSkillSummary {
    param([string]$Name,[string]$Description,[string]$Category)
    if($Description -match '[\p{IsCJKUnifiedIdeographs}]'){
        $first=($Description -split '[。；;\r\n]')[0].Trim()
        if($first.Length -gt 42){$first=$first.Substring(0,42)+'…'}
        return $first
    }
    $key=$Name.ToLowerInvariant();$text=($Name+' '+$Description).ToLowerInvariant()
    $exact=@{
        'problem-framing-canvas'='梳理问题边界、用户目标和真正需要解决的核心问题'
        'craft-spec'='把零散想法整理成清晰、可执行的产品需求文档'
        'agent-orchestration-advisor'='设计多代理分工、交接、监控和失败处理流程'
        'code-review-excellence'='系统审查代码质量、风险、缺陷和改进方向'
        'verification-before-completion'='完成前核对证据，防止未经验证就宣布完成'
        'product-design:audit'='依据真实截图检查产品流程、UI 细节和可访问性'
        'product-design:image-to-code'='按照选定截图或设计稿还原可运行界面'
        'design-system'='统一颜色、字体、间距和组件状态等设计规范'
        'skill-installer'='从可信目录或 GitHub 安装 Codex Skills'
    }
    if($exact.ContainsKey($key)){return $exact[$key]}
    $rules=@(
        @{Terms=@('image-to-code','figma','frontend','ui','ux','visual','design');Text='用于界面设计、视觉还原和交互细节处理'},
        @{Terms=@('prd','product','roadmap','persona','priorit','user-stor');Text='用于产品需求、用户价值、范围和优先级判断'},
        @{Terms=@('test','debug','review','quality','verification','playwright');Text='用于测试、调试、质量检查和完成前验证'},
        @{Terms=@('architecture','api','database','backend','migration','refactor');Text='用于代码架构、接口、数据和工程改造'},
        @{Terms=@('metric','analytics','data','dashboard','kpi','experiment');Text='用于数据分析、指标设计和实验判断'},
        @{Terms=@('market','competitor','position','pricing','strategy');Text='用于市场、竞品、定位、定价和策略分析'},
        @{Terms=@('document','pdf','presentation','report','writing','content');Text='用于文档、报告、演示和内容整理'},
        @{Terms=@('security','reverse','binary','pentest','exploit','firmware');Text='用于安全检查、逆向分析和风险排查'},
        @{Terms=@('agent','orchestrat','workflow','context');Text='用于代理协作、任务编排和上下文管理'}
    )
    foreach($rule in $rules){foreach($term in $rule.Terms){if($text.Contains($term)){return $rule.Text}}}
    $fallback = switch($Category){
        '产品经理' { '用于产品分析、需求整理和决策支持' }
        '界面设计' { '用于界面设计、体验检查和视觉实现' }
        '测试调试' { '用于测试、调试和质量验证' }
        '架构开发' { '用于代码开发、架构设计和工程维护' }
        '数据分析' { '用于数据处理、指标分析和结果解释' }
        '安全逆向' { '用于安全分析、逆向和风险检查' }
        '文档内容' { '用于文档、内容和报告处理' }
        default { '通用辅助能力；可结合名称判断具体用途' }
    }
    return $fallback
}

function Get-CodexSkillCatalog {
    param([string]$CodexHome = (Join-Path $env:USERPROFILE '.codex'))
    $skillsRoot = Join-Path $CodexHome 'skills'
    if (-not (Test-Path -LiteralPath $skillsRoot)) { return @() }

    $sources = @([pscustomobject]@{Root=$skillsRoot;Prefix=''})
    $productDesignCache = Join-Path $CodexHome 'plugins\cache\openai-curated-remote\product-design'
    if (Test-Path -LiteralPath $productDesignCache) {
        $latest = Get-ChildItem -LiteralPath $productDesignCache -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
        if ($latest) { $sources += [pscustomobject]@{Root=(Join-Path $latest.FullName 'skills');Prefix='product-design:'} }
    }

    $result = foreach ($source in $sources) { foreach ($file in Get-ChildItem -LiteralPath $source.Root -Recurse -Filter 'SKILL.md' -File -ErrorAction SilentlyContinue) {
        $meta = Get-SkillMetadata -SkillFile $file.FullName
        if ($null -ne $meta) {
            $displayName = if ($source.Prefix) { $source.Prefix + $meta.Name } else { $meta.Name }
            $category = Get-SkillCategory -Name $displayName -Description $meta.Description
            [pscustomobject]@{
                Name = $displayName
                Description = $meta.Description
                ChineseSummary = Get-ChineseSkillSummary -Name $displayName -Description $meta.Description -Category $category
                Category = $category
                Path = $meta.Path
            }
        }
    } }
    @($result | Sort-Object Name -Unique)
}

function Get-IntentProfiles {
    @(
        @{ Category='界面设计'; Triggers=@('原型','设计稿','截图','界面','网页','页面','app','应用','ui','ux','还原','前端'); Skills=@('product-design:image-to-code','image-to-code','design-system','redesign-existing-projects','ui-ux-pro-max','verification-before-completion') },
        @{ Category='产品经理'; Triggers=@('需求','产品','prd','功能','用户故事','路线图','竞品','优先级','原型流程'); Skills=@('prd','craft-spec','user-story','epic-breakdown-advisor','roadmap-planning','prioritization-advisor') },
        @{ Category='架构开发'; Triggers=@('源码','代码','架构','重构','接口','数据库','迁移','模块','依赖','后端'); Skills=@('architecture-patterns','writing-plans','api-design-principles','architecture-decision-records','database-migration','monorepo-management') },
        @{ Category='测试调试'; Triggers=@('bug','报错','错误','修复','调试','测试','回归','验收','审查'); Skills=@('systematic-debugging','test-driven-development','code-review-excellence','e2e-testing-patterns','verification-before-completion') },
        @{ Category='数据分析'; Triggers=@('数据','指标','看板','分析','增长','留存','转化','实验'); Skills=@('build-metric-tree','north-star-metric','metrics-analyzer','diagnose-retention','craft-experiment-design') }
    )
}

function Get-WorkModeProfiles {
    @{
        '托管任务'=@('problem-framing-canvas','craft-spec','agent-orchestration-advisor','code-review-excellence','verification-before-completion')
        '产品判断'=@('problem-framing-canvas','craft-spec','prd','create-user-stories','prioritization-advisor','verification-before-completion')
        'UI 检查'=@('product-design:audit','design-system','impeccable','code-review-excellence','e2e-testing-patterns','verification-before-completion')
        'Skills'=@('skill-installer','agent-orchestration-advisor','verification-before-completion')
    }
}

function Find-CodexSkills {
    param(
        [Parameter(Mandatory)][object[]]$Catalog,
        [AllowEmptyString()][string]$Query,
        [string]$Mode = '自动判断',
        [int]$Top = 6
    )

    $queryText = $Query.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($queryText) -and $Mode -eq '自动判断') {
        $defaults = @('product-design:image-to-code','prd','architecture-patterns','systematic-debugging','test-driven-development','verification-before-completion')
        return @($defaults | ForEach-Object { $wanted=$_; $Catalog | Where-Object Name -eq $wanted | Select-Object -First 1 } | Where-Object { $null -ne $_ })
    }
    if ([string]::IsNullOrWhiteSpace($queryText)) { $queryText=$Mode.ToLowerInvariant() }

    $scores = @{}
    $orderedNames = New-Object 'System.Collections.Generic.List[string]'
    foreach ($skill in $Catalog) { $scores[$skill.Name] = 0 }
    $modeProfiles = Get-WorkModeProfiles
    if ($Mode -ne '自动判断' -and $modeProfiles.ContainsKey($Mode)) {
        foreach ($skillName in $modeProfiles[$Mode]) {
            if ($scores.ContainsKey($skillName)) {
                $scores[$skillName] += 160
                if (-not $orderedNames.Contains($skillName)) { $orderedNames.Add($skillName) }
            }
        }
    }
    foreach ($profile in Get-IntentProfiles) {
        $intentMatch = $false
        foreach ($trigger in $profile.Triggers) { if ($queryText.Contains($trigger)) { $intentMatch = $true; break } }
        if ($intentMatch) {
            foreach ($skillName in $profile.Skills) {
                if ($scores.ContainsKey($skillName)) {
                    $scores[$skillName] += 100
                    if (-not $orderedNames.Contains($skillName)) { $orderedNames.Add($skillName) }
                }
            }
            foreach ($skill in $Catalog) { if ($skill.Category -eq $profile.Category) { $scores[$skill.Name] += 12 } }
        }
    }

    $tokens = @($queryText -split '[\s,，。；;、:/]+' | Where-Object Length -ge 2)
    foreach ($skill in $Catalog) {
        $chineseSummary=if($skill.PSObject.Properties['ChineseSummary']){$skill.ChineseSummary}else{''}
        $haystack = ($skill.Name + ' ' + $skill.Description + ' ' + $chineseSummary + ' ' + $skill.Category).ToLowerInvariant()
        foreach ($token in $tokens) { if ($haystack.Contains($token)) { $scores[$skill.Name] += 30 } }
    }

    $ordered = @($orderedNames | ForEach-Object { $wanted=$_; $Catalog | Where-Object Name -eq $wanted | Select-Object -First 1 })
    $remaining = @($Catalog | Where-Object { -not $orderedNames.Contains($_.Name) } | ForEach-Object {
        [pscustomobject]@{ Skill=$_; Score=$scores[$_.Name] }
    } | Where-Object Score -gt 0 | Sort-Object Score, @{Expression={$_.Skill.Name}} -Descending | ForEach-Object Skill)
    @($ordered + $remaining | Select-Object -First $Top)
}

function New-CodexTaskPrompt {
    param([string]$Task, [object[]]$Skills, [string]$Mode='托管任务')
    $names = @($Skills | ForEach-Object Name)
    $skillLine = if ($names.Count) { $names -join '、' } else { '请自动选择合适的 skills' }
    $modeContract = switch ($Mode) {
        '产品判断' { '你是独立的产品审查者。禁止奉承或只给笼统的“可以优化”。先区分事实、推断和建议，再检查用户目标、功能范围、流程、信息结构、异常状态和决策风险。每个问题都说明证据、影响、建议和优先级；信息不足时明确指出，不要自行编造页面。' }
        'UI 检查' { '你是严格的 UI 验收者。开始前必须取得并查看截图、Figma 原型或现有界面；没有视觉证据时先索取，不能凭文字猜设计。检查裁切、溢出、对齐、间距、字体、圆角、颜色、交互状态和不同窗口尺寸。修改后提供同状态前后截图并再次检查。' }
        'Skills' { '先解释为什么选择这些 skills、各自负责什么以及执行顺序。只选择完成任务所需的最小组合，避免为了展示能力增加无关流程。' }
        default { '你是任务总管。先把口语需求整理成目标、不可改变项、执行步骤、风险边界和验收标准，再开始工作。普通分析、测试和明显错误修复可以继续；新增页面、删除或覆盖重要内容、偏离原型、需要密钥或存在明显方案分歧时必须暂停并用通俗中文询问。不要伪造进度或预计时间。' }
    }
    @"
任务：$Task
工作模式：$Mode

请优先组合使用这些 skills：$skillLine。
$modeContract

开始前先检查现有项目、相似组件和设计规范；说明选择这些 skills 的原因以及准备采用的工作顺序。实施过程中保留现有功能，避免无关改动。完成后运行与风险相匹配的测试；涉及界面时必须检查裁切、溢出、间距、字体、交互状态、键盘焦点和视觉一致性，并完成截图验收。最后用中文报告修改内容、验证证据、仍存在的限制，以及真正需要我决定的事项。
"@.Trim()
}

Export-ModuleMember -Function Get-CodexSkillCatalog, Find-CodexSkills, New-CodexTaskPrompt
