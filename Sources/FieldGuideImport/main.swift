import CompendiumImport
import CreatureImport
import Foundation

/// `FieldGuideImport [--pf2e DIR] [--foundry-app DIR] [--scrollkeeper DIR] [--out DIR]`
///
/// Defaults: `~/git/pf2e`, the Foundry app in /Applications, Scrollkeeper's downloads and `Generated`. Also writes
/// the creatures for the battle cards to `<out>/Creatures` (Tabletop Kit's `CreatureImport`). Creature art isn't
/// imported: the app reads it from the user's own PDFs on the device.
let home = FileManager.default.homeDirectoryForCurrentUser
var settings = [
    "--pf2e": home.appendingPathComponent("git/pf2e").path,
    "--foundry-app": "/Applications/Foundry Virtual Tabletop.app/Contents/Resources/app/public",
    "--scrollkeeper": home.appendingPathComponent("Library/Application Support/Scrollkeeper/Files").path,
    "--out": "Generated"
]
var arguments = CommandLine.arguments.dropFirst()
while let flag = arguments.popFirst() {
    guard settings[flag] != nil, let value = arguments.popFirst() else {
        FileHandle.standardError.write(Data("Importing failed: unknown option \(flag)\n".utf8))
        exit(2)
    }
    settings[flag] = value
}

let scrollkeeper = URL(fileURLWithPath: settings["--scrollkeeper"]!)
let options = ImportOptions(
    paths: FoundryPaths(repository: URL(fileURLWithPath: settings["--pf2e"]!),
                        appPublic: URL(fileURLWithPath: settings["--foundry-app"]!)),
    scrollkeeperFiles: FileManager.default.fileExists(atPath: scrollkeeper.path) ? scrollkeeper : nil,
    output: URL(fileURLWithPath: settings["--out"]!)
)
let creatures = ImportConfiguration(repository: options.paths.repository,
                                    outputDirectory: options.output.appendingPathComponent("Creatures"),
                                    configurationDirectory: URL(fileURLWithPath: "."))
do {
    let report = try CompendiumImporter(options: options).run()
    print(report.summary)
    try FileManager.default.createDirectory(at: creatures.outputDirectory, withIntermediateDirectories: true)
    let creatureReport = try BestiaryImporter(configuration: creatures).run()
    print("Wrote \(creatureReport.creatureCount) creatures for the battle cards.")
} catch {
    FileHandle.standardError.write(Data("Importing failed: \(error)\n".utf8))
    exit(1)
}
