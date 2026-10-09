// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FieldGuide",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "FieldGuideKit", targets: ["FieldGuideKit"])
    ],
    targets: [
        .target(name: "FieldGuideKit"),
        .target(name: "CompendiumImport", dependencies: ["FieldGuideKit"]),
        .testTarget(name: "FieldGuideKitTests", dependencies: ["FieldGuideKit"]),
        .testTarget(name: "CompendiumImportTests", dependencies: ["CompendiumImport"])
    ]
)
