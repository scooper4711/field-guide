import ArtExtractionTestSupport
import CoreGraphics
import CreatureArt
import FieldGuideKit
import Foundation
import SharedLibraries
import Testing
@testable import FieldGuideUI

/// Art whose PDF is on another device, drawn from pictures downloaded from iCloud (R6.8).
@Suite("Pictures from iCloud")
@MainActor
struct CloudPictureTests {
    private let data = DataLocation(folder: FileManager.default.temporaryDirectory
        .appendingPathComponent("NoData-\(UUID())"))
    private let subject = "pf2e.pack.goblin-warrior"

    /// A shared library whose goblin was read from a PDF that has since gone, with its picture removed, as on a
    /// device that has the art's record but neither the PDF nor the picture. The cloud holds the picture.
    private func libraryWithoutPicture() throws -> LibraryWithoutPicture {
        let fixture = try SharedLibraryFixture()
        let goblin = DrawnPawn(rect: CGRect(x: 20, y: 600, width: 81, height: 138), art: creatureArt(variant: 0),
                               name: "GOBLIN WARRIOR")
        let pdf = try writePawnPDF([goblin], named: "Pathfinder Test Pawn Box PDF.pdf", in: temporaryFolder())
        try fixture.library.add(pdf, keeping: false)
        try FileManager.default.removeItem(at: pdf)
        let entry = try #require(try fixture.library.artEntries().first)
        let name = try #require(entry.picture)
        let file = fixture.library.pictureFile(name)
        let cloud = FakePictureCloud(pictures: [name: try Data(contentsOf: file)], folder: file
            .deletingLastPathComponent())
        try FileManager.default.removeItem(at: file)
        try fixture.library.setCreatureArt(.library(entry.id), for: subject)
        return LibraryWithoutPicture(fixture: fixture, cloud: cloud, id: entry.id)
    }

    private struct LibraryWithoutPicture {
        let fixture: SharedLibraryFixture
        let cloud: FakePictureCloud
        /// The art lacking its picture.
        let id: UUID
    }

    private func model(_ fixture: SharedLibraryFixture, cloud: FakePictureCloud?) throws -> ArtModel {
        let store = try CreatureArtStore(sharedLibraryIn: fixture.folder, app: .fieldGuide)
        let model = ArtModel(data: data, store: store, sharedLibrary: fixture.library)
        model.pictureFetcher = cloud
        return model
    }

    @Test("A picture this device lacks is downloaded and drawn")
    func downloadsAndDraws() async throws {
        let setup = try libraryWithoutPicture()
        let model = try model(setup.fixture, cloud: setup.cloud)
        #expect(await model.picture(forCreature: subject, maxPixels: 64) != nil)
        #expect(await setup.cloud.asked.count == 1)
    }

    @Test("Without syncing, art without its picture draws nothing")
    func withoutSyncing() async throws {
        let model = try model(try libraryWithoutPicture().fixture, cloud: nil)
        #expect(await model.picture(forCreature: subject, maxPixels: 64) == nil)
    }

    @Test("A picture no device has uploaded isn't asked for again within a minute")
    func waitsBeforeAskingAgain() async throws {
        let setup = try libraryWithoutPicture()
        let empty = FakePictureCloud(pictures: [:], folder: setup.fixture.folder)
        let model = try model(setup.fixture, cloud: empty)
        #expect(await model.picture(forCreature: subject, maxPixels: 64) == nil)
        #expect(await model.picture(forCreature: subject, maxPixels: 64) == nil)
        #expect(await empty.asked.count == 1)

        model.cloudPictureAttempts[setup.id] = Date().addingTimeInterval(-ArtModel.cloudPictureRetry - 1)
        #expect(await model.fetchCloudPictures(ofArt: setup.id) == false)
        #expect(await empty.asked.count == 2)
    }

    @Test("Art that has its pictures, or that the library doesn't hold, isn't asked for")
    func nothingToAsk() async throws {
        let setup = try libraryWithoutPicture()
        let model = try model(setup.fixture, cloud: setup.cloud)
        #expect(await model.fetchCloudPictures(ofArt: UUID()) == false)
        #expect(await model.fetchCloudPictures(ofArt: setup.id))
        #expect(await model.fetchCloudPictures(ofArt: setup.id) == false)
        #expect(await setup.cloud.asked.count == 1)
    }

    @Test("Syncing starts only in a build that names the container, so never in the tests")
    func noSyncInTests() throws {
        let model = try model(try libraryWithoutPicture().fixture, cloud: nil)
        model.isInSharedLibrary = true
        model.startCloudSync()
        model.resumeCloudSync()
        #expect(model.librarySync == nil && model.cloudAccountObserver == nil)
    }
}

/// iCloud's pictures zone, as `LibrarySync.fetchPictures(named:)` reaches it: hands over the pictures it holds by
/// writing them to the library's pictures folder.
actor FakePictureCloud: PictureFetching {
    private let pictures: [String: Data]
    private let folder: URL
    private(set) var asked: [[String]] = []

    init(pictures: [String: Data], folder: URL) {
        self.pictures = pictures
        self.folder = folder
    }

    func fetchPictures(named names: [String]) async -> Set<String> {
        asked.append(names)
        var arrived: Set<String> = []
        for name in names {
            guard let picture = pictures[name] else { continue }
            try? picture.write(to: folder.appendingPathComponent(name))
            arrived.insert(name)
        }
        return arrived
    }
}
