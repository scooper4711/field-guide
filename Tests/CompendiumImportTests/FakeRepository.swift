import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import CompendiumImport

/// A small pf2e repository, Foundry install and Turnkeeper output in a temporary folder.
struct FakeRepository {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("FieldGuideTests-\(UUID().uuidString)")
    var repository: URL { root.appendingPathComponent("pf2e") }
    var appPublic: URL { root.appendingPathComponent("app") }
    var output: URL { root.appendingPathComponent("Generated") }
    var rexardPacks: URL { root.appendingPathComponent("rexard") }
    var religiousSymbols: URL { root.appendingPathComponent("Religious Symbols") }
    var actionIconsFont: URL { root.appendingPathComponent("Artwork/pathfinder-icons/Pathfinder-Icons.ttf") }
    var paths: FoundryPaths { FoundryPaths(repository: repository, appPublic: appPublic) }

    init() throws {
        try writeManifests()
        try writeLanguage()
        try write("src/scripts/config/traits.ts", in: repository, text: """
            export const traitDescriptions = {
                fire: "PF2E.TraitDescriptionFire",
            };
            const weaponDescriptions = {
                deadly: "PF2E.TraitDescriptionDeadly",
            };
            """)
        try writeJSON("build/duplicates.json", in: repository, [
            ["publication": "Starfinder Player Core", "entries": ["spells": ["Fireball"]]],
            ["publication": NSNull(), "entries": ["conditions": ["Frightened"], "feats": ["Missing Feat"]]]
        ])
        for font in ["pathfinder-2e-actions.woff2", "gelasio-regular.woff2", "eczar.woff2"] {
            try write("static/fonts/\(font)", in: repository, text: "font")
        }
        try write("pathfinder-icons/Pathfinder-Icons.ttf", in: root.appendingPathComponent("Artwork"), text: "font")
        try write("static/icons/spells/fireball.webp", in: repository, text: "icon")
        try Pattern.rising.write(to: appPublic.appendingPathComponent("icons/weapons/sword.webp"), size: 40)
        try Pattern.rising.write(to: rexardPacks.appendingPathComponent("Weapons/sword.png"), size: 96)
        try Pattern.falling.write(to: religiousSymbols.appendingPathComponent("Abadar.png"), size: 48)
        try writeDocuments()
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    private func writeManifests() throws {
        func pack(_ name: String, _ folder: String, _ type: String) -> [String: String] {
            ["name": name, "path": "packs/\(folder)", "type": type]
        }
        try writeJSON("system.pf2e.json", in: repository, ["packs": [
            pack("spells-srd", "spells", "Item"), pack("feats-srd", "feats", "Item"),
            pack("equipment-srd", "equipment", "Item"), pack("conditionitems", "conditions", "Item"),
            pack("actionspf2e", "actions", "Item"), pack("classes", "classes", "Item"),
            pack("ancestries", "ancestries", "Item"), pack("heritages", "heritages", "Item"),
            pack("backgrounds", "backgrounds", "Item"), pack("deities", "deities", "Item"),
            pack("spell-effects", "spell-effects", "Item"), pack("journals", "journals", "JournalEntry"),
            pack("pathfinder-monster-core", "pathfinder-monster-core", "Actor"), pack("hazards", "hazards", "Actor")
        ]])
        try writeJSON("system.sf2e.json", in: repository, ["packs": [
            pack("spells", "spells", "Item"), pack("conditions", "conditions", "Item"),
            pack("starfinder-society-bestiary", "starfinder-society-bestiary", "Actor")
        ]])
    }

    private func writeLanguage() throws {
        try writeJSON("static/lang/en.json", in: repository, ["PF2E": [
            "TraitFire": "Fire", "TraitDescriptionFire": "Effects with this trait deal fire damage.",
            "TraitDeadlyD10": "Deadly d10", "TraitDescriptionDeadly": "<p>On a critical hit, add a die.</p>",
            "Greeting": "Hello from @Localize[PF2E.Nested]", "Nested": "the lang file"
        ]])
        try writeJSON("static/lang/sf2e-overrides-en.json", in: repository, ["PF2E": ["TraitFire": "Plasma"]])
    }

    private func writeDocuments() throws {
        for (path, document) in Documents.all {
            try writeJSON("packs/\(path).json", in: repository, document)
        }
        try writeJSON("packs/pf2e/spells/_folders.json", in: repository, [["name": "Folder"]])
    }

    func write(_ path: String, in folder: URL, text: String) throws {
        let url = folder.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    func writeJSON(_ path: String, in folder: URL, _ object: Any) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        try write(path, in: folder, text: String(bytes: data, encoding: .utf8) ?? "")
    }

    static func writePNG(to url: URL, width: Int, height: Int) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.3, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        CGImageDestinationFinalize(destination)
    }
}

extension FakeRepository {
    /// A GM Screen journal: a heading page, two pages with text linking each other, and an empty page.
    func writeGMScreen() throws {
        let filler = String(repeating: "Some rules text. ", count: 10)
        // swiftlint:disable:next function_parameter_count - a fixture row reads best with every field named
        func page(_ id: String, _ name: String, level: Int, sort: Int, text: String) -> [String: Any] {
            ["_id": id, "name": name, "sort": sort, "title": ["level": level], "text": ["content": text]]
        }
        try writeJSON("packs/pf2e/journals/gm-screen.json", in: repository, ["_id": "gm1", "pages": [
            page("p3", "DCs by Level", level: 2, sort: 30, text: "<p>\(filler)See @UUID[.p2]{Simple DCs}.</p>"),
            page("p1", "Running the Game", level: 1, sort: 10, text: "<p>Sources</p>"),
            page("p2", "Simple DCs", level: 2, sort: 20,
                 text: "<table><tr><td>Trained</td><td>15</td></tr></table><p>\(filler)</p>"),
            page("p4", "Empty", level: 2, sort: 40, text: ""),
            page("p5", "Counteracting", level: 2, sort: 50,
                 text: "<p>\(filler)</p><p><strong>Critical Failure</strong> You fail to counteract the target.</p>")
        ]])
    }

    /// The other rules journals: the Elf and Fighter pages (whose entries the fake packs hold) and the
    /// Ancestries index linking the Elf page, one page each of Archetypes, Domains, Remaster Changes and the Hero
    /// Point Deck, and a Classes page no class is named for.
    func writeRulesJournals() throws {
        struct Page {
            let id: String
            let name: String
            let text: String
        }
        let filler = String(repeating: "Some rules text. ", count: 10)
        func journal(_ file: String, _ id: String, _ name: String, _ pages: [Page]) throws {
            try writeJSON("packs/pf2e/journals/\(file).json", in: repository, ["_id": id, "name": name, "pages":
                pages.enumerated().map { index, page in
                    ["_id": page.id, "name": page.name, "sort": index,
                     "text": ["content": "<p>\(filler)\(page.text)</p>"]]
                }])
        }
        try journal("ancestries", "an1", "Ancestries", [Page(id: "anI", name: "Index", text: "See @UUID[.anE]{Elf}."),
                                                         Page(id: "anE", name: "Elf", text: "Elves live long lives.")])
        try journal("classes", "cl1", "Classes", [Page(id: "clF", name: "Fighter", text: "Fighters train hard."),
                                                  Page(id: "clD", name: "Draconic Connections", text: "Dragons.")])
        try journal("archetypes", "ar1", "Archetypes", [Page(id: "arA", name: "Acrobat", text: "Tumbling.")])
        try journal("domains", "do1", "Domains", [Page(id: "doF", name: "Fire Domain", text: "Flames.")])
        try journal("remaster-changes", "re1", "Remaster Changes",
                    [Page(id: "reS", name: "Spells", text: "Renamed spells.")])
        try journal("hero-point-deck", "he1", "Hero Point Deck", [Page(id: "heC", name: "Last Stand", text: "A card.")])
    }
}
