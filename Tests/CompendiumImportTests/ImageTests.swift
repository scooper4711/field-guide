import Foundation
import Testing
@testable import CompendiumImport

@Suite struct ImageTests {
    @Test func resolvesFoundryPaths() {
        let paths = FoundryPaths(repository: URL(fileURLWithPath: "/r"), appPublic: URL(fileURLWithPath: "/a"))
        #expect(paths.file(for: "systems/sf2e/icons/x.webp")?.path == "/r/static/icons/x.webp")
        #expect(paths.file(for: "icons/svg/a%20b.svg")?.path == "/a/icons/svg/a b.svg")
        // Foundry modules' art is Paizo's, which the app may not ship.
        #expect(paths.file(for: "modules/m/x.webp") == nil)
        #expect(paths.file(for: "https://example.com/x.webp") == nil && paths.file(for: "") == nil)
    }

    @Test func copiesIconsOnce() throws {
        let repository = try FakeRepository()
        defer { repository.remove() }
        let images = ImageCollector(paths: repository.paths, output: repository.output)
        #expect(images.icon("icons/weapons/sword.webp") == "icons/weapons/sword.webp")
        #expect(images.icon("icons/weapons/sword.webp") == "icons/weapons/sword.webp")
        #expect(images.icon("systems/pf2e/icons/default.svg").isEmpty && images.icon("").isEmpty)
        #expect(images.icon("icons/none.webp").isEmpty && images.missing == ["icons/none.webp": 1])
    }
}
