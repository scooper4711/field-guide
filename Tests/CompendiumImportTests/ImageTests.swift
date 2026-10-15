import Foundation
import Testing
@testable import CompendiumImport

@Suite struct ImageTests {
    @Test func searchesPathBeforeHomebrew() {
        #expect(ArtScaler.searchFolders(path: "/custom/bin:/usr/bin")
            == ["/custom/bin", "/usr/bin"] + ArtScaler.homebrewFolders)
        #expect(ArtScaler.searchFolders(path: nil) == ArtScaler.homebrewFolders)
    }

    @Test func findsTheFirstExecutableOfThatName() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ArtScalerTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let folders = ["empty", "tool", "not-executable"].map { root.appendingPathComponent($0) }
        for folder in folders { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
        let tool = folders[1].appendingPathComponent("cwebp")
        try Data().write(to: tool)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tool.path)
        try Data().write(to: folders[2].appendingPathComponent("cwebp"))
        #expect(ArtScaler.executable(named: "cwebp", in: folders.map(\.path)) == tool.path)
        #expect(ArtScaler.executable(named: "missing", in: folders.map(\.path)) == nil)
    }

    @Test func resolvesFoundryPaths() {
        let paths = FoundryPaths(repository: URL(fileURLWithPath: "/r"), appPublic: URL(fileURLWithPath: "/a"))
        #expect(paths.file(for: "systems/sf2e/icons/x.webp")?.path == "/r/static/icons/x.webp")
        #expect(paths.file(for: "icons/svg/a%20b.svg")?.path == "/a/icons/svg/a b.svg")
        // Foundry modules' art is Paizo's, which the app may not ship.
        #expect(paths.file(for: "modules/m/x.webp") == nil)
        #expect(paths.file(for: "https://example.com/x.webp") == nil && paths.file(for: "") == nil)
    }

    @Test func copiesTheChosenRexardIconsOnceAsWebP() throws {
        let fixture = try IconFixture()
        defer { fixture.remove() }
        let sword = IconFixture.document("ls", "Longsword", type: "weapon", img: "icons/weapons/sword.webp")
        let other = IconFixture.document("ot", "Other", type: "weapon", img: "icons/other.webp")
        let gone = IconFixture.document("gn", "Gone", type: "weapon", img: "icons/gone.webp")
        let map = IconMap(documents: [sword, other, gone], sources: fixture.sources(overrides: [
            "icons/gone.webp": "Missing/gone.png"
        ]))
        let output = fixture.root.appendingPathComponent("Images")
        let images = ImageCollector(icons: map, packs: fixture.packs, output: output)
        #expect(images.icon(of: sword) == "rexard/Weapons/sword.webp")
        #expect(images.icon(of: sword) == "rexard/Weapons/sword.webp")
        #expect(ArtScaler.pixelSize(of: output.appendingPathComponent("rexard/Weapons/sword.webp"))?.width == 96)
        #expect(images.icon(of: other).isEmpty && images.icon(of: gone).isEmpty)
        #expect(ImageCollector(icons: map, packs: nil, output: output).icon(of: sword).isEmpty)
    }

    @Test func copiesDeitiesSymbolsOnceAsWebP() throws {
        let fixture = try IconFixture()
        let symbols = try SymbolFixture()
        defer {
            fixture.remove()
            symbols.remove()
        }
        let output = fixture.root.appendingPathComponent("Images")
        let images = ImageCollector(icons: IconMap(documents: [], sources: fixture.sources()), packs: nil,
                                    output: output)
        images.symbols = symbols.symbols
        let thamir = IconFixture.document("th", "Thamir", type: "deity", img: "", category: .deities)
        #expect(images.symbol(of: thamir) == "symbols/pf2e/Thamir Gixx.webp")
        #expect(images.symbol(of: thamir) == "symbols/pf2e/Thamir Gixx.webp")
        #expect(ArtScaler.pixelSize(of: output.appendingPathComponent("symbols/pf2e/Thamir Gixx.webp"))?.width == 24)
        let nobody = IconFixture.document("nb", "Nobody", type: "deity", img: "", category: .deities)
        #expect(images.symbol(of: nobody).isEmpty)
    }
}
