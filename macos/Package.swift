// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CodexSkillHelper",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "CodexSkillHelper", targets: ["CodexSkillHelper"])],
    targets: [
        .executableTarget(name: "CodexSkillHelper", resources: [.copy("Resources/StarterSkills")]),
        .testTarget(name: "CodexSkillHelperTests", dependencies: ["CodexSkillHelper"])
    ]
)
