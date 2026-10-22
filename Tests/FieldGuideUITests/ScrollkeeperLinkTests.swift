import Foundation
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
        let link = ScrollkeeperLink(launcher: FakeLauncher())
        link.receiveIndex(file)
        #expect(link.owns(sku: "PZO13003E") && !link.owns(sku: "PZO9303WS") && !link.owns(sku: nil))
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
        let link = ScrollkeeperLink(launcher: FakeLauncher())
        link.open(sku: "X")
        link.receiveStatus(try #require(URL(string: url)))
        #expect(link.requested?.status == status)
        link.receiveStatus(try #require(URL(string: "fieldguide://handoff?sku=X&state=done")))
        #expect(link.requested == nil)
    }
}
