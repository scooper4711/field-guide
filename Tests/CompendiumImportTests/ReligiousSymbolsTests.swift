import Foundation
import Testing
@testable import CompendiumImport

/// Religious Symbols folders for both systems in a temporary folder.
struct SymbolFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("FieldGuideSymbols-\(UUID().uuidString)")
    var pathfinder: URL { root.appendingPathComponent("Religious Symbols") }
    var starfinder: URL { root.appendingPathComponent("Starfinder Religious Symbols") }
    var symbols: ReligiousSymbols { ReligiousSymbols(pathfinder: pathfinder, starfinder: starfinder) }

    init() throws {
        for name in ["Abadar.png", "Thamir Gixx.png", "Devourer.png", "Desna.png", "Gorum.jpg"] {
            try Pattern.rising.write(to: pathfinder.appendingPathComponent(name), size: 24)
        }
        try Pattern.falling.write(to: starfinder.appendingPathComponent("Abadar.png"), size: 24)
    }

    func remove() { try? FileManager.default.removeItem(at: root) }
}

@Suite struct ReligiousSymbolsTests {
    @Test func findsADeitysSymbolByItsName() throws {
        let fixture = try SymbolFixture()
        defer { fixture.remove() }
        let symbols = fixture.symbols
        #expect(symbols.file(forDeity: "Abadar", in: .pathfinder) == fixture.pathfinder.appendingPathComponent(
            "Abadar.png"))
        #expect(symbols.file(forDeity: "Thamir", in: .pathfinder)?.lastPathComponent == "Thamir Gixx.png")
        #expect(symbols.file(forDeity: "The Devourer", in: .pathfinder)?.lastPathComponent == "Devourer.png")
        // Only PNGs, which keep the symbols' transparency, and only whole words.
        #expect(symbols.file(forDeity: "Gorum", in: .pathfinder) == nil)
        #expect(symbols.file(forDeity: "Thami", in: .pathfinder) == nil)
        #expect(symbols.file(forDeity: "Nobody", in: .starfinder) == nil)
    }

    @Test func starfinderDeitiesLookInTheStarfinderFolderFirst() throws {
        let fixture = try SymbolFixture()
        defer { fixture.remove() }
        #expect(fixture.symbols.file(forDeity: "Abadar", in: .starfinder) == fixture.starfinder
            .appendingPathComponent("Abadar.png"))
        #expect(fixture.symbols.file(forDeity: "Desna", in: .starfinder) == fixture.pathfinder
            .appendingPathComponent("Desna.png"))
    }

    @Test func missingFoldersHaveNoSymbols() {
        let symbols = ReligiousSymbols(pathfinder: URL(fileURLWithPath: "/nonexistent"), starfinder: nil)
        #expect(symbols.file(forDeity: "Abadar", in: .pathfinder) == nil)
        #expect(ReligiousSymbols().file(forDeity: "Abadar", in: .starfinder) == nil)
    }
}
