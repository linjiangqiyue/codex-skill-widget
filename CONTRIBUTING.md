# 参与贡献

谢谢你愿意帮助这个项目。第一次参与开源也完全没关系。

## 适合贡献的内容

- 更准确、更自然的中文 Skill 用途说明；
- Windows 不同分辨率、缩放比例下的界面问题；
- 产品判断、UI 检查和托管提示词的改进；
- GitHub 候选 Skill 的安全检查规则；
- 测试、文档和无障碍改进。

## 提交前

1. 先创建 Issue，说明问题、使用场景和预期结果；小型修复可直接提交 PR。
2. 不要提交查询历史、设置、日志、隔离下载目录、凭据或个人数据。
3. 保持界面轻量，不随意增加页面和按钮。
4. 涉及 UI 时，请附修改前后截图和所用窗口尺寸。

## 本地验证

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\UsageAdapter.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\SkillCatalog.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\GitHubSkillSync.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\ReleasePackage.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\Start-CodexSkillWidget.ps1 -ValidateOnly
```

提交 PR 时，请说明改了什么、为什么改、如何验证，以及仍然存在的限制。
