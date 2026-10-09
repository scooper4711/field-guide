import CompendiumImport
import Foundation

/// `FieldGuideImport [--pf2e DIR] [--foundry-app DIR] [--foundry-data DIR] [--combat-pad DIR] [--out DIR]`
///
/// Defaults: `~/git/pf2e`, the Foundry app in /Applications, Foundry's data folder in Application Support,
/// `~/git/combat-pad/Generated` and `Generated`.
let home = FileManager.default.homeDirectoryForCurrentUser
var settings = [
    "--pf2e": home.appendingPathComponent("git/pf2e").path,
    "--foundry-app": "/Applications/Foundry Virtual Tabletop.app/Contents/Resources/app/public",
    "--foundry-data": home.appendingPathComponent("Library/Application Support/FoundryVTT/Data").path,
    "--combat-pad": home.appendingPathComponent("git/combat-pad/Generated").path,
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

let combatPad = URL(fileURLWithPath: settings["--combat-pad"]!)
let options = ImportOptions(
    paths: FoundryPaths(repository: URL(fileURLWithPath: settings["--pf2e"]!),
                        appPublic: URL(fileURLWithPath: settings["--foundry-app"]!),
                        data: URL(fileURLWithPath: settings["--foundry-data"]!)),
    combatPadGenerated: FileManager.default.fileExists(atPath: combatPad.path) ? combatPad : nil,
    output: URL(fileURLWithPath: settings["--out"]!)
)
do {
    let report = try CompendiumImporter(options: options).run()
    print(report.summary)
} catch {
    FileHandle.standardError.write(Data("Importing failed: \(error)\n".utf8))
    exit(1)
}
