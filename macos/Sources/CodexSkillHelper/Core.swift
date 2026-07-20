import Foundation

struct Skill: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let description: String
    let path: String
    var category: String { SkillCatalog.category(name: name, description: description) }
    var chineseSummary: String { SkillCatalog.chineseSummary(name: name, description: description, category: category) }
}

enum WorkMode: String, CaseIterable, Identifiable {
    case managed = "托管任务", product = "产品判断", ui = "UI 检查", skills = "能力库"
    var id: String { rawValue }
}

enum SkillCatalog {
    static func parse(_ text: String, path: String = "") -> Skill? {
        let lines = text.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return nil }
        var name: String?, description: String?
        for line in lines.dropFirst().prefix(79) {
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }
            let pair = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { continue }
            let value = pair[1].trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "\"'")))
            if pair[0] == "name" { name = value }
            if pair[0] == "description" { description = value }
        }
        guard let name, !name.isEmpty, let description, !description.isEmpty else { return nil }
        return Skill(name: name, description: description, path: path)
    }

    static func load(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [Skill] {
        let roots: [(URL, String)] = [(home.appendingPathComponent(".codex/skills"), "")] + productDesignRoots(home: home)
        var result: [String: Skill] = [:]
        for (root, prefix) in roots {
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let file as URL in walker where file.lastPathComponent == "SKILL.md" {
                guard let data = try? String(contentsOf: file, encoding: .utf8), var skill = parse(data, path: file.path) else { continue }
                if !prefix.isEmpty { skill = Skill(name: prefix + skill.name, description: skill.description, path: skill.path) }
                result[skill.name] = skill
            }
        }
        return result.values.sorted { $0.name < $1.name }
    }

    private static func productDesignRoots(home: URL) -> [(URL, String)] {
        let cache = home.appendingPathComponent(".codex/plugins/cache/openai-curated-remote/product-design")
        let versions = (try? FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: nil)) ?? []
        guard let latest = versions.sorted(by: { $0.lastPathComponent > $1.lastPathComponent }).first else { return [] }
        return [(latest.appendingPathComponent("skills"), "product-design:")]
    }

    static func category(name: String, description: String) -> String {
        let text = (name + " " + description).lowercased()
        let rules = [("产品经理", ["product","prd","roadmap","persona","market"]), ("测试调试", ["test","debug","review","verification","quality"]), ("架构开发", ["architecture","api","database","backend","migration"]), ("界面设计", ["design","ui","ux","frontend","visual"]), ("数据分析", ["analytics","metric","data","dashboard","kpi"]), ("安全逆向", ["reverse","binary","pentest","security","exploit"]), ("文档内容", ["document","pdf","presentation","report","content"])]
        return rules.first { $0.1.contains(where: text.contains) }?.0 ?? "通用工具"
    }

    static func chineseSummary(name: String, description: String, category: String) -> String {
        let exact = [
            "problem-framing-canvas": "梳理问题边界、用户目标和真正需要解决的核心问题",
            "craft-spec": "把零散想法整理成清晰、可执行的产品需求文档",
            "agent-orchestration-advisor": "设计多代理分工、交接、监控和失败处理流程",
            "code-review-excellence": "系统审查代码质量、风险、缺陷和改进方向",
            "verification-before-completion": "完成前核对证据，防止未经验证就宣布完成",
            "product-design:audit": "依据真实截图检查产品流程、UI 细节和可访问性",
            "product-design:image-to-code": "按照选定截图或设计稿还原可运行界面",
            "design-system": "统一颜色、字体、间距和组件状态等设计规范",
            "skill-installer": "从可信目录或 GitHub 安装 Codex Skills"
        ]
        if let value = exact[name.lowercased()] { return value }
        if description.range(of: "[\\p{Han}]", options: .regularExpression) != nil { return String(description.prefix(42)) }
        return ["产品经理":"用于产品分析、需求整理和决策支持", "界面设计":"用于界面设计、体验检查和视觉实现", "测试调试":"用于测试、调试和质量验证", "架构开发":"用于代码开发、架构设计和工程维护", "数据分析":"用于数据处理、指标分析和结果解释", "安全逆向":"用于安全分析、逆向和风险检查", "文档内容":"用于文档、内容和报告处理"][category] ?? "通用辅助能力；可结合名称判断具体用途"
    }

    static let profiles: [WorkMode: [String]] = [
        .managed: ["problem-framing-canvas","craft-spec","agent-orchestration-advisor","code-review-excellence","verification-before-completion"],
        .product: ["problem-framing-canvas","craft-spec","prd","create-user-stories","prioritization-advisor","verification-before-completion"],
        .ui: ["product-design:audit","design-system","impeccable","code-review-excellence","e2e-testing-patterns","verification-before-completion"],
        .skills: ["skill-installer","agent-orchestration-advisor","verification-before-completion"]
    ]

    static func recommend(_ catalog: [Skill], query: String, mode: WorkMode, limit: Int = 6) -> [Skill] {
        if mode == .skills { return query.isEmpty ? catalog : catalog.filter { ($0.name + $0.description + $0.chineseSummary + $0.category).localizedCaseInsensitiveContains(query) } }
        let preferred = profiles[mode] ?? []
        var ordered = preferred.compactMap { wanted in catalog.first { $0.name == wanted } }
        let matches = catalog.filter { !ordered.contains($0) && ($0.name + $0.description + $0.chineseSummary + $0.category).localizedCaseInsensitiveContains(query) }
        ordered.append(contentsOf: matches)
        return Array(ordered.prefix(limit))
    }
}

enum PromptComposer {
    static func make(task: String, mode: WorkMode, skills: [Skill]) -> String {
        let names = skills.isEmpty ? "请自动选择合适的 skills" : skills.map(\.name).joined(separator: "、")
        let contract: String
        switch mode {
        case .product: contract = "你是独立的产品审查者。禁止奉承或只给笼统的“可以优化”。先区分事实、推断和建议，再检查用户目标、功能范围、流程、信息结构、异常状态和决策风险。每个问题都说明证据、影响、建议和优先级；信息不足时明确指出，不要自行编造页面。"
        case .ui: contract = "你是严格的 UI 验收者。开始前必须取得并查看截图、Figma 原型或现有界面；没有视觉证据时先索取，不能凭文字猜设计。检查裁切、溢出、对齐、间距、字体、圆角、颜色、交互状态和不同窗口尺寸。修改后提供同状态前后截图并再次检查。"
        case .skills: contract = "先解释为什么选择这些 skills、各自负责什么以及执行顺序。只选择完成任务所需的最小组合，避免为了展示能力增加无关流程。"
        case .managed: contract = "你是任务总管。先把口语需求整理成目标、不可改变项、执行步骤、风险边界和验收标准，再开始工作。新增页面、删除或覆盖重要内容、偏离原型、需要密钥或存在明显方案分歧时必须暂停并用通俗中文询问。不要伪造进度或预计时间。"
        }
        return """
        任务：\(task)
        工作模式：\(mode.rawValue)

        请优先组合使用这些 skills：\(names)。
        \(contract)

        开始前先检查现有项目、相似组件和设计规范；说明选择这些 skills 的原因以及准备采用的工作顺序。实施过程中保留现有功能，避免无关改动。完成后运行与风险相匹配的测试；涉及界面时必须检查裁切、溢出、间距、字体、交互状态、键盘焦点和视觉一致性，并完成截图验收。最后用中文报告修改内容、验证证据、仍存在的限制，以及真正需要我决定的事项。
        """
    }
}
