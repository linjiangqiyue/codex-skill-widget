# 推广自动化

这套工具实现的是“自动准备、人工发布、数据复盘”的安全闭环，不会登录知乎、小红书、B 站或社区账号，也不会自动群发内容。

## 每周自动完成

1. 读取 GitHub Star、Fork、近 14 天访问与克隆、Release 下载和开放反馈。
2. 从四个真实用户痛点中轮换本周主题。
3. 生成知乎、B 站、小红书、V2EX/掘金的差异化草稿。
4. 为每个平台生成独立 UTM 链接。
5. 更新同一个“推广闭环周报”Issue，并上传 Markdown 文件作为工作流产物。

GitHub Actions 默认每周一北京时间 09:00 运行，也可在 Actions 页面手动触发。

首次启用与两周复盘步骤见[上线清单](launch-checklist-growth-loop.md)。

## 本地生成

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\New-MarketingBrief.ps1
```

生成文件保存在本地 `marketing-output` 目录，该目录不会提交到 Git。

## 为什么不自动发布

- 不同平台需要账号授权，接口和规则也会变化；
- 同一段内容跨平台群发会降低质量，并可能触发风控；
- 自动生成的事实和语气必须由作者确认；
- 评论中的真实问题比自动排期更重要。

如果未来接入发布 API，应坚持“预览 → 人工确认 → 单平台发布 → 保存结果”的流程，并把凭据放在平台 Secrets 中，绝不能写进仓库。
