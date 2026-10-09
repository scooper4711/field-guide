import Foundation

/// Where creature art comes from, by creature key `<system>.<pack folder>.<id>`: Combat Pad's import (Foundry
/// token modules, then art from the Paizo PDFs), else the token modules' own art mappings.
public struct ArtSource: Sendable {
    private var files: [String: URL] = [:]

    public init(files: [String: URL] = [:]) {
        self.files = files
    }

    /// Combat Pad's `Generated` folder first, then every module's `compendiumArtMappings`.
    public init(combatPadGenerated: URL?, foundryData: URL) {
        var files = combatPadGenerated.map(Self.combatPadArt) ?? [:]
        for (key, file) in Self.moduleArt(foundryData: foundryData) where files[key] == nil { files[key] = file }
        self.files = files
    }

    public func art(for key: String) -> URL? { files[key] }

    public var count: Int { files.count }

    /// Portrait, else the Battle Card's art, from `Bestiary/index.json`.
    static func combatPadArt(_ generated: URL) -> [String: URL] {
        guard let index = try? JSONValue(contentsOf: generated.appendingPathComponent("Bestiary/index.json")) else {
            return [:]
        }
        var files: [String: URL] = [:]
        for entry in index["entries"].array {
            let path = [entry[path: "art.portrait"].string, entry[path: "art.cardBack"].string].first { !$0.isEmpty }
            guard let path else { continue }
            let file = generated.appendingPathComponent(path)
            if FileManager.default.fileExists(atPath: file.path) { files[entry["key"].string] = file }
        }
        return files
    }

    /// Every installed module's actor art mapping, later modules (alphabetically) losing to earlier ones.
    static func moduleArt(foundryData: URL) -> [String: URL] {
        let modules = foundryData.appendingPathComponent("modules")
        let names = ((try? FileManager.default.contentsOfDirectory(atPath: modules.path)) ?? []).sorted()
        var files: [String: URL] = [:]
        for name in names.reversed() {
            for (key, file) in mappings(of: modules.appendingPathComponent(name),
                                        data: foundryData) { files[key] = file }
        }
        return files
    }

    private static func mappings(of module: URL, data: URL) -> [String: URL] {
        let manifestURL = module.appendingPathComponent("module.json")
        guard let manifest = try? JSONValue(contentsOf: manifestURL) else { return [:] }
        var files: [String: URL] = [:]
        for (system, settings) in manifest[path: "flags.compendiumArtMappings"].object {
            let mappingURL = data.appendingPathComponent(settings["mapping"].string)
            guard let mapping = try? JSONValue(contentsOf: mappingURL) else {
                continue
            }
            for (pack, actors) in mapping.object {
                let parts = pack.split(separator: ".", maxSplits: 1).map(String.init)
                guard parts.count == 2, parts[0] == system else { continue }
                for (actorID, entry) in actors.object {
                    let path = entry["actor"].string.removingPercentEncoding ?? entry["actor"].string
                    let file = data.appendingPathComponent(path)
                    if !path.isEmpty, FileManager.default.fileExists(atPath: file.path) {
                        files["\(system).\(parts[1]).\(actorID)"] = file
                    }
                }
            }
        }
        return files
    }
}
