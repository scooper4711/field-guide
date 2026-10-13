// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FieldGuide",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "FieldGuideKit", targets: ["FieldGuideKit"]),
        .library(name: "FieldGuideUI", targets: ["FieldGuideUI"]),
        .executable(name: "FieldGuide", targets: ["FieldGuide"]),
        .executable(name: "FieldGuideImport", targets: ["FieldGuideImport"])
    ],
    dependencies: [
        .package(url: "https://github.com/scooper4711/tabletop-kit.git", from: "0.10.0")
    ],
    targets: [
        .target(name: "FieldGuideKit"),
        .target(name: "CompendiumImport", dependencies: [
            "FieldGuideKit", .product(name: "Bestiary", package: "tabletop-kit")
        ]),
        .executableTarget(name: "FieldGuideImport", dependencies: [
            "CompendiumImport", .product(name: "CreatureImport", package: "tabletop-kit")
        ]),
        .target(name: "FieldGuideUI", dependencies: [
            "FieldGuideKit", .product(name: "BattleCards", package: "tabletop-kit"),
            .product(name: "Bestiary", package: "tabletop-kit"), .product(name: "CreatureArt", package: "tabletop-kit")
        ], resources: [.process("Resources")]),
        .executableTarget(name: "FieldGuide", dependencies: ["FieldGuideUI"]),
        .testTarget(name: "FieldGuideKitTests", dependencies: ["FieldGuideKit"]),
        .testTarget(name: "CompendiumImportTests", dependencies: ["CompendiumImport"]),
        .testTarget(name: "FieldGuideUITests", dependencies: ["FieldGuideUI", "FieldGuideKit"])
    ]
)
