import Foundation
#if os(macOS)
import AppKit
#endif
import TablesideShared
import Testing
@testable import FieldGuideUI

@Suite("Asking Scrollkeeper for sourcebooks")
@MainActor
struct ScrollkeeperLinkTests {
    /// Records what the link asks the system to open.
    final class FakeLauncher: ApplicationLauncher {
        var installed = true
        var opened: [URL] = []

        func isInstalled(_ bundleIdentifier: String) -> Bool { installed }
        func openInBackground(_ url: URL) { opened.append(url) }
    }

    @Test("Field Guide asks for the list and for a title as Scrollkeeper's contract says")
    func requests() throws {
        let launcher = FakeLauncher()
        let link = ScrollkeeperLink(launcher: launcher)
        link.requestIndex()
        link.open(sku: "PZO13003WS")
        #expect(launcher.opened.map(\.absoluteString) == [
            "scrollkeeper://index?app=fieldguide", "scrollkeeper://open?sku=PZO13003WS&app=fieldguide"
        ])
        #expect(link.requested?.status == "Asking Scrollkeeper…")
    }

    @Test("Without Scrollkeeper nothing is asked and nothing is owned")
    func notInstalled() {
        let launcher = FakeLauncher()
        launcher.installed = false
        let link = ScrollkeeperLink(launcher: launcher)
        link.requestIndex()
        #expect(launcher.opened.isEmpty && !link.isInstalled && !link.owns(sku: "PZO13003E"))
        // Without the list, whether the user lacks a title is unknown.
        #expect(!link.lacks(sku: "PZO13003E"))
        #expect(!ScrollkeeperLink(launcher: nil).isInstalled)
    }

    @Test("The list Scrollkeeper hands over says which titles the user owns")
    func receivesTheIndex() throws {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("fieldguide-\(UUID()).scrollkeeperindex")
        defer { try? FileManager.default.removeItem(at: file) }
        let json = #"{"formatVersion": 1, "generatedAt": "2026-10-22T03:00:00Z", "titles": ["#
            + #"{"sku": "PZO13003E", "title": "Divine Mysteries", "kind": "Lost Omens", "downloaded": false}]}"#
        try Data(json.utf8).write(to: file)
        let link = ScrollkeeperLink(launcher: ScrollkeeperLinkTests.FakeLauncher())
        link.receiveIndex(file)
        #expect(link.owns(sku: "PZO13003E") && !link.owns(sku: "PZO9303WS") && !link.owns(sku: nil))
        #expect(link.lacks(sku: "PZO9303WS") && !link.lacks(sku: "PZO13003E") && !link.lacks(sku: nil))
        link.receiveIndex(file.appendingPathExtension("missing"))
        #expect(link.owned == ["PZO13003E": false])
    }

    @Test("Status links say how the request is going", arguments: [
        ("fieldguide://handoff?sku=X&state=downloading&fraction=0.5", "Scrollkeeper is downloading… 50%"),
        ("fieldguide://handoff?sku=X&state=failed&reason=Signed%20out", "Scrollkeeper couldn't open it: Signed out"),
        ("fieldguide://handoff?sku=Y&state=done", "Asking Scrollkeeper…"),
        ("other://handoff?sku=X&state=done", "Asking Scrollkeeper…")
    ])
    func status(link url: String, status: String) throws {
        let link = ScrollkeeperLink(launcher: ScrollkeeperLinkTests.FakeLauncher())
        link.open(sku: "X")
        link.receiveStatus(try #require(URL(string: url)))
        #expect(link.requested?.status == status)
        link.receiveStatus(try #require(URL(string: "fieldguide://handoff?sku=X&state=done")))
        #expect(link.requested == nil)
    }
}

@Suite("Finding Scrollkeeper")
@MainActor
struct ScrollkeeperLinkStandardTests {
    @Test("The app's link asks the system whether Scrollkeeper is installed")
    func standard() {
        let link = ScrollkeeperLink.standard()
        #if os(macOS)
        #expect(link.isInstalled == (NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: ScrollkeeperLink.bundleIdentifier) != nil))
        #else
        #expect(!link.isInstalled)
        #endif
        #expect(link.owned.isEmpty && link.requested == nil)
    }

    @Test("Scrollkeeper's library list in the App Group says what the user owns, without asking Scrollkeeper")
    func readsTheSharedLibrary() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Scrollkeeper-\(UUID())")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let library = ScrollkeeperLibrary(generatedAt: Date(), downloadFolder: .init(isShared: true), titles: [
            Self.title("PZO13003E", downloaded: true), Self.title("PZO2101E", downloaded: false)
        ])
        try library.encoded().write(to: folder.appendingPathComponent(ScrollkeeperLibrary.fileName))
        let link = ScrollkeeperLink(launcher: nil)
        link.readSharedLibrary(in: folder)
        #expect(link.owned == ["PZO13003E": true, "PZO2101E": false])
        #expect(link.lacks(sku: "PZO9999E") && !link.downloadsOnRequest)
    }

    @Test("Without a library list, what the user owns stays unknown", arguments: [false, true])
    func noSharedLibrary(hasFolder: Bool) {
        let link = ScrollkeeperLink(launcher: ScrollkeeperLinkTests.FakeLauncher())
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Missing-\(UUID())")
        link.readSharedLibrary(in: hasFolder ? folder : nil)
        #expect(link.owned.isEmpty && link.downloadsOnRequest)
    }

    private static func title(_ sku: String, downloaded: Bool) -> ScrollkeeperLibrary.Title {
        ScrollkeeperLibrary.Title(sku: sku, title: sku, kind: "Rulebooks", gameSystem: "Pathfinder 2E",
                                  downloaded: downloaded, editions: [])
    }
}
