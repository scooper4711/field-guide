import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import CompendiumImport

/// A small pf2e repository, Foundry install and Combat Pad output in a temporary folder.
struct FakeRepository {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("FieldGuideTests-\(UUID().uuidString)")
    var repository: URL { root.appendingPathComponent("pf2e") }
    var appPublic: URL { root.appendingPathComponent("app") }
    var data: URL { root.appendingPathComponent("data") }
    var combatPad: URL { root.appendingPathComponent("combat-pad") }
    var output: URL { root.appendingPathComponent("Generated") }
    var paths: FoundryPaths { FoundryPaths(repository: repository, appPublic: appPublic, data: data) }

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
        try write("static/icons/spells/fireball.webp", in: repository, text: "icon")
        try write("icons/weapons/sword.webp", in: appPublic, text: "icon")
        try Self.writePNG(to: combatPad.appendingPathComponent("Art/goblin.png"), width: 900, height: 600)
        try writeJSON("Bestiary/index.json", in: combatPad, ["entries": [
            ["key": "pf2e.pathfinder-monster-core.goblin1", "art": ["portrait": "Art/goblin.png", "cardBack": ""]]
        ]])
        try writeModule()
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

    private func writeModule() throws {
        try writeJSON("modules/tokens/module.json", in: data, ["flags": ["compendiumArtMappings": [
            "pf2e": ["mapping": "modules/tokens/mapping.json"]
        ]]])
        try writeJSON("modules/tokens/mapping.json", in: data, [
            "pf2e.hazards": ["trap1": ["actor": "modules/tokens/art/trap.png"]],
            "sf2e.hazards": ["ignored": ["actor": "modules/tokens/art/trap.png"]]
        ])
        try Self.writePNG(to: data.appendingPathComponent("modules/tokens/art/trap.png"), width: 200, height: 300)
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
            page("p4", "Empty", level: 2, sort: 40, text: "")
        ]])
    }

    /// A two-page PDF in Scrollkeeper's layout; the second page is labeled "2".
    func writePlayerCore(folder: String) throws -> URL {
        let url = root.appendingPathComponent("Files/\(folder)/Book.pdf")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var box = CGRect(x: 0, y: 0, width: 200, height: 300)
        let context = CGContext(url as CFURL, mediaBox: &box, nil)!
        for gray in [0.2, 0.6] {
            context.beginPDFPage(nil)
            context.setFillColor(CGColor(gray: gray, alpha: 1))
            context.fill(box)
            context.endPDFPage()
        }
        context.closePDF()
        try write("Files/\(folder)/Extract.pdf", in: root, text: "small")
        return url
    }
}
