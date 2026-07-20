$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot '..\src\SkillCatalog.psm1') -Force

$catalog = @(Get-CodexSkillCatalog)
if (@($catalog | Where-Object {[string]::IsNullOrWhiteSpace($_.ChineseSummary)}).Count) { throw '每个 Skill 都必须有中文用途说明' }
$problemFraming=$catalog|Where-Object Name -eq 'problem-framing-canvas'|Select-Object -First 1
$craftSpec=$catalog|Where-Object Name -eq 'craft-spec'|Select-Object -First 1
if($problemFraming.ChineseSummary -notmatch '[\p{IsCJKUnifiedIdeographs}]'){throw 'problem-framing-canvas 缺少中文说明'}
if($craftSpec.ChineseSummary -notmatch '[\p{IsCJKUnifiedIdeographs}]'){throw 'craft-spec 缺少中文说明'}
$chineseSearch=@(Find-CodexSkills -Catalog $catalog -Query '整理产品需求文档' -Mode 'Skills' -Top 20)
if(-not ($chineseSearch.Name -contains 'craft-spec')){throw '中文用途搜索应找到 craft-spec'}
$architecture = $catalog | Where-Object Name -eq 'architecture-patterns' | Select-Object -First 1
if ($null -eq $architecture) { throw 'architecture-patterns test fixture is missing' }
if ($architecture.Category -ne '架构开发') {
    throw "RED: architecture-patterns should be 架构开发, got $($architecture.Category)"
}

$debugging = $catalog | Where-Object Name -eq 'systematic-debugging' | Select-Object -First 1
if ($null -eq $debugging) { throw 'systematic-debugging test fixture is missing' }
if ($debugging.Category -ne '测试调试') {
    throw "systematic-debugging should be 测试调试, got $($debugging.Category)"
}

$uiAudit = @(Find-CodexSkills -Catalog $catalog -Query '看看细节' -Mode 'UI 检查' -Top 6)
if ($uiAudit.Count -eq 0 -or $uiAudit[0].Name -ne 'product-design:audit') {
    throw "UI 检查模式应优先 product-design:audit，实际为 $(@($uiAudit.Name) -join ', ')"
}

$featureDesign = @(Find-CodexSkills -Catalog $catalog -Query '增加功能' -Mode '产品判断' -Top 6)
if (-not ($featureDesign.Name -contains 'craft-spec')) { throw '产品判断模式应包含 craft-spec' }

$managedPrompt=New-CodexTaskPrompt -Task '按原型修改页面' -Skills @($architecture) -Mode '托管任务'
if($managedPrompt -notmatch '新增页面' -or $managedPrompt -notmatch '必须暂停'){throw '托管提示词缺少范围和暂停护栏'}
$productPrompt=New-CodexTaskPrompt -Task '检查产品' -Skills @() -Mode '产品判断'
if($productPrompt -notmatch '禁止奉承' -or $productPrompt -notmatch '事实、推断和建议'){throw '产品判断提示词缺少独立审查要求'}
$uiPrompt=New-CodexTaskPrompt -Task '检查界面' -Skills @() -Mode 'UI 检查'
if($uiPrompt -notmatch '截图' -or $uiPrompt -notmatch '裁切'){throw 'UI 检查提示词缺少视觉证据要求'}

Write-Output 'PASS: Skill category behavior tests'
