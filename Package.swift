// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FieldGuide",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "FieldGuideKit", targets: ["FieldGuideKit"]),
        .library(name: "FieldGuideUI", targets: ["FieldGuideUI"]),
        .executable(name: "FieldGuide", targets: ["FieldGuide"]),
        .executable(name: "FieldGuideImport", targets: ["FieldGuideImport"]),
        .executable(name: "FieldGuideLoreSurvey", targets: ["FieldGuideLoreSurvey"])
    ],
    dependencies: [
        .package(url: "https://github.com/scooper4711/tabletop-kit.git", from: "0.14.2")
    ],
    targets: [
        .target(name: "FieldGuideKit"),
        .target(name: "SourcebookLore", dependencies: [.product(name: "ArtExtraction", package: "tabletop-kit")],
                resources: [.process("Resources")]),
        .executableTarget(name: "FieldGuideLoreSurvey", dependencies: ["SourcebookLore", "FieldGuideKit"]),
        .target(name: "CompendiumImport", dependencies: [
            "FieldGuideKit", .product(name: "Bestiary", package: "tabletop-kit"),
            .product(name: "CreatureImport", package: "tabletop-kit")
        ]),
        .executableTarget(name: "FieldGuideImport", dependencies: [
            "CompendiumImport", .product(name: "CreatureImport", package: "tabletop-kit")
        ]),
        .target(name: "FieldGuideUI", dependencies: [
            "FieldGuideKit", "SourcebookLore", .product(name: "BattleCards", package: "tabletop-kit"),
            .product(name: "Bestiary", package: "tabletop-kit"), .product(name: "CreatureArt", package: "tabletop-kit"),
            .product(name: "AppNotices", package: "tabletop-kit")
        ], resources: [.process("Resources")]),
        .executableTarget(name: "FieldGuide", dependencies: ["FieldGuideUI"]),
        .testTarget(name: "FieldGuideKitTests", dependencies: ["FieldGuideKit"]),
        .target(name: "SourcebookLoreTestSupport", dependencies: ["SourcebookLore"]),
        .testTarget(name: "SourcebookLoreTests", dependencies: ["SourcebookLore", "SourcebookLoreTestSupport"]),
        .testTarget(name: "CompendiumImportTests", dependencies: ["CompendiumImport"]),
        .testTarget(name: "FieldGuideUITests", dependencies: [
            "FieldGuideUI", "FieldGuideKit", "SourcebookLore", "SourcebookLoreTestSupport"
        ])
    ]
)
