import XCTest
@testable import CodexSkillHelper

final class CoreTests: XCTestCase {
    func testParsesFrontmatter() {
        let skill = SkillCatalog.parse("---\nname: craft-spec\ndescription: Make specs\n---\n# Body")
        XCTAssertEqual(skill?.name, "craft-spec")
        XCTAssertEqual(skill?.description, "Make specs")
    }
    func testRejectsInvalidFrontmatter() { XCTAssertNil(SkillCatalog.parse("name: broken")) }
    func testChineseMapping() {
        let skill = Skill(name: "product-design:audit", description: "Audit UI", path: "")
        XCTAssertTrue(skill.chineseSummary.contains("截图"))
    }
    func testModeRecommendationOrderAndLimit() {
        let catalog = ["verification-before-completion","craft-spec","problem-framing-canvas"].map { Skill(name: $0, description: "tool", path: $0) }
        XCTAssertEqual(SkillCatalog.recommend(catalog, query: "", mode: .managed).map(\.name), ["problem-framing-canvas","craft-spec","verification-before-completion"])
    }
    func testChineseSearchAndAllSkillsMode() {
        let skill = Skill(name: "prd", description: "product", path: "")
        XCTAssertEqual(SkillCatalog.recommend([skill], query: "产品", mode: .skills).count, 1)
        XCTAssertEqual(SkillCatalog.recommend([skill], query: "", mode: .skills).count, 1)
    }
    func testPromptContract() {
        let prompt = PromptComposer.make(task: "检查页面", mode: .ui, skills: [])
        XCTAssertTrue(prompt.contains("没有视觉证据时先索取"))
        XCTAssertTrue(prompt.contains("不要伪造" ) == false)
    }
    func testEmptyCatalog() { XCTAssertTrue(SkillCatalog.recommend([], query: "界面", mode: .ui).isEmpty) }
    func testStarterPackIsBundled() {
        let root = StarterSkillInstaller.bundledRoot()
        XCTAssertNotNil(root)
        let children = root.flatMap { try? FileManager.default.contentsOfDirectory(at: $0, includingPropertiesForKeys: nil) } ?? []
        XCTAssertGreaterThanOrEqual(children.count, 5)
    }
}
