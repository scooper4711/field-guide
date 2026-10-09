// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FieldGuide",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [
        .library(name: "FieldGuideKit", targets: ["FieldGuideKit"]),
        .executable(name: "FieldGuideImport", targets: ["FieldGuideImport"])
    ],
    targets: [
        .target(name: "FieldGuideKit"),
        .target(name: "CompendiumImport", dependencies: ["FieldGuideKit"]),
        .executableTarget(name: "FieldGuideImport", dependencies: ["CompendiumImport"]),
        .testTarget(name: "FieldGuideKitTests", dependencies: ["FieldGuideKit"]),
        .testTarget(name: "CompendiumImportTests", dependencies: ["CompendiumImport"])
    ]
)
