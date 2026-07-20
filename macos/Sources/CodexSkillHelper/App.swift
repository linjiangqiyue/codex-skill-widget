import SwiftUI
import AppKit

@MainActor final class AppState: ObservableObject {
    @Published var skills: [Skill] = []
    @Published var mode: WorkMode = .managed
    @Published var query = ""
    @Published var size = 1
    var recommendations: [Skill] { SkillCatalog.recommend(skills, query: query, mode: mode) }
    func reload() { skills = SkillCatalog.load() }
    func copyPrompt() {
        let task = query.isEmpty ? "请根据我的下一条中文需求选择合适的 skills" : query
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(PromptComposer.make(task: task, mode: mode, skills: recommendations), forType: .string)
    }
}

@main struct CodexSkillHelperApp: App {
    @StateObject private var state = AppState()
    var body: some Scene {
        MenuBarExtra("Codex 助手", systemImage: "wand.and.stars") {
            Button("打开助手") { NSApp.activate(ignoringOtherApps: true); NSApp.windows.first?.makeKeyAndOrderFront(nil) }
            Button("重新扫描 Skills") { state.reload() }
            Divider()
            Button("退出") { NSApp.terminate(nil) }
        }
        Window("Codex Skill 中文助手", id: "main") {
            WidgetView(state: state).onAppear { state.reload(); NSApp.windows.first?.level = .floating }
        }
        .defaultSize(width: 420, height: 560)
        .windowResizability(.contentSize)
    }
}

struct WidgetView: View {
    @ObservedObject var state: AppState
    private var width: CGFloat { [350, 420, 500][state.size] }
    private var height: CGFloat { [430, 560, 650][state.size] }
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars")
                Text("Codex 助手").font(.headline)
                Text("\(state.skills.count) 个可用").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(["小","中","大"][state.size]) { state.size = (state.size + 1) % 3 }.buttonStyle(.borderless).help("切换窗口尺寸")
            }
            HStack { Image(systemName: "gauge.with.dots.needle.33percent"); Text("剩余额度"); Text("--%").fontWeight(.semibold); Spacer(); Text("额度暂不可用").font(.caption).foregroundStyle(.secondary) }
                .padding(10).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            Picker("模式", selection: $state.mode) { ForEach(WorkMode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            TextField("用中文描述你想做什么…", text: $state.query).textFieldStyle(.roundedBorder)
            HStack { Text(state.mode == .skills ? "能力库" : "\(state.mode.rawValue) · 推荐顺序").fontWeight(.semibold); Spacer(); Button("重新扫描") { state.reload() }.buttonStyle(.borderless) }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(state.recommendations.enumerated()), id: \.element.id) { index, skill in
                        HStack(alignment: .top, spacing: 10) {
                            Text(String(format: "%02d", index + 1)).font(.caption).foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 3) { Text(skill.name).fontWeight(.semibold); Text("用途：\(skill.chineseSummary)").font(.caption).foregroundStyle(.secondary) }
                            Spacer()
                        }.padding(.vertical, 9)
                        Divider()
                    }
                }
            }
            HStack { Text(state.recommendations.isEmpty ? "没有匹配项" : "从 \(state.skills.count) 个中显示 \(state.recommendations.count) 个").font(.caption).foregroundStyle(.secondary); Spacer(); Button("复制提示词") { state.copyPrompt() }.buttonStyle(.borderedProminent) }
        }
        .padding(16).frame(width: width, height: height)
        .background(.ultraThinMaterial)
    }
}
