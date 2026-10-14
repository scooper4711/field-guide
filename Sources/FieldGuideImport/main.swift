import CompendiumImport
import CreatureImport
import Foundation

/// `FieldGuideImport [--pf2e DIR] [--foundry-app DIR] [--rexard DIR] [--symbols DIR]
/// [--starfinder-symbols DIR] [--artwork DIR] [--out DIR] [--work DIR]`
///
/// Defaults: `~/git/pf2e`, the Foundry app in /Applications, `~/git/rexard-packs`, the
/// Community Use Package's Religious Symbols and Starfinder Religious Symbols in
/// `~/git/community-use-artwork`, the `Artwork` submodule (for Paizo's Pathfinder-Icons font), `Generated` and
/// `.build/field-guide-import`, which keeps the Rexard hash cache and `icon-map.tsv` (each entry's icon and why)
/// out of the app. Entries show the user's Rexard icons in place
/// of Foundry's; `icon-overrides.json` corrects them, and `icon-matches.tsv` keeps the matches for machines
/// without the Foundry app. Also writes the creatures for the battle cards to
/// `<out>/Creatures` (Tabletop Kit's `CreatureImport`). Creature art isn't imported: the app reads it from the
/// user's own PDFs on the device.
let home = FileManager.default.homeDirectoryForCurrentUser
var settings = [
    "--pf2e": home.appendingPathComponent("git/pf2e").path,
    "--foundry-app": "/Applications/Foundry Virtual Tabletop.app/Contents/Resources/app/public",
    "--rexard": home.appendingPathComponent("git/rexard-packs").path,
    "--symbols": home.appendingPathComponent(
        "git/community-use-artwork/Community Use Package- Religious Symbols").path,
    "--starfinder-symbols": home.appendingPathComponent(
        "git/community-use-artwork/Community Use Package- Starfinder Religious Symbols").path,
    "--artwork": "Artwork",
    "--out": "Generated",
    "--work": ".build/field-guide-import"
]
var arguments = CommandLine.arguments.dropFirst()
while let flag = arguments.popFirst() {
    guard settings[flag] != nil, let value = arguments.popFirst() else {
        FileHandle.standardError.write(Data("Importing failed: unknown option \(flag)\n".utf8))
        exit(2)
    }
    settings[flag] = value
}

/// The folder at a path, or nil when it doesn't exist.
func existingFolder(_ path: String?) -> URL? {
    guard let path, FileManager.default.fileExists(atPath: path) else { return nil }
    return URL(fileURLWithPath: path)
}

var options = ImportOptions(
    paths: FoundryPaths(repository: URL(fileURLWithPath: settings["--pf2e"]!),
                        appPublic: URL(fileURLWithPath: settings["--foundry-app"]!)),
    output: URL(fileURLWithPath: settings["--out"]!),
    workFolder: URL(fileURLWithPath: settings["--work"]!)
)
options.rexardPacks = existingFolder(settings["--rexard"])
options.actionIconsFont = existingFolder(settings["--artwork"])?
    .appendingPathComponent("pathfinder-icons/Pathfinder-Icons.ttf")
options.religiousSymbols = ReligiousSymbols(pathfinder: existingFolder(settings["--symbols"]),
                                            starfinder: existingFolder(settings["--starfinder-symbols"]))
let creatures = ImportConfiguration(repository: options.paths.repository,
                                    outputDirectory: options.output.appendingPathComponent("Creatures"),
                                    configurationDirectory: URL(fileURLWithPath: "."))
do {
    options.iconOverrides = try IconSources.overrides(in: URL(fileURLWithPath: "icon-overrides.json"))
    options.iconMatchesFile = URL(fileURLWithPath: "icon-matches.tsv")
    let report = try CompendiumImporter(options: options).run()
    print(report.summary)
    try FileManager.default.createDirectory(at: creatures.outputDirectory, withIntermediateDirectories: true)
    let creatureReport = try BestiaryImporter(configuration: creatures).run()
    print("Wrote \(creatureReport.creatureCount) creatures for the battle cards.")
} catch {
    FileHandle.standardError.write(Data("Importing failed: \(error)\n".utf8))
    exit(1)
}
