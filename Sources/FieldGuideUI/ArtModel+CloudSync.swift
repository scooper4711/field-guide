import CloudKit
import CoreGraphics
import Foundation
import SharedLibraries
import TablesideSync

/// Downloads pictures from iCloud (`LibrarySync`), or stands in for it in tests, which can't reach CloudKit.
protocol PictureFetching: Sendable {
    /// Downloads those of `names` the device lacks, notes all of them as shown, and returns those downloaded.
    func fetchPictures(named names: [String]) async -> Set<String>
}

extension LibrarySync: PictureFetching {}

/// Syncing the shared library, and with it the art's pictures, between the user's devices (R6.7): through the
/// toolkit's engine, started once the shared library has opened.
extension ArtModel {
    /// How long a picture that didn't arrive isn't asked for again: no device may have uploaded it yet, and a
    /// screen of art would otherwise ask at every draw.
    static let cloudPictureRetry: TimeInterval = 60

    /// Starts syncing where the build names the container and the device has an iCloud account, and tries again
    /// when the account changes (R6.7). Only in the shared library, never outside the App Group or in the tests.
    public func startCloudSync() {
        guard isInSharedLibrary, sharedLibrary != nil, !LibrarySync.bundleContainer.isEmpty else { return }
        if cloudAccountObserver == nil {
            cloudAccountObserver = NotificationCenter.default.addObserver(
                forName: .CKAccountChanged, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.connectCloudSync() }
            }
        }
        connectCloudSync()
    }

    /// The art's picture from the art library, downloaded from iCloud first when this device lacks it (R6.8).
    func libraryPicture(id: UUID, maxPixels: Int) async -> CGImage? {
        guard let store else { return nil }
        if let image = await store.picture(id: id, maxPixels: maxPixels) { return image }
        guard await fetchCloudPictures(ofArt: id) else { return nil }
        return await store.picture(id: id, maxPixels: maxPixels)
    }

    /// Downloads the pictures of art this device lacks; true when any arrived. Art whose pictures didn't arrive
    /// isn't asked for again for `cloudPictureRetry` seconds.
    func fetchCloudPictures(ofArt id: UUID) async -> Bool {
        guard let pictureFetcher, let sharedLibrary,
              Date().timeIntervalSince(cloudPictureAttempts[id] ?? .distantPast) > Self.cloudPictureRetry,
              let entry = try? sharedLibrary.artEntry(id: id) else { return false }
        let names = sharedLibrary.missingPictures(of: entry)
        guard !names.isEmpty else { return false }
        cloudPictureAttempts[id] = Date()
        let arrived = await pictureFetcher.fetchPictures(named: names)
        guard !arrived.isEmpty else { return false }
        cloudPictureAttempts[id] = nil
        return true
    }

    /// Lets go of the shared library in the background, as the rest of the app does (shared libraries R5.4).
    func closeCloudSync() async {
        await librarySync?.close()
    }

    /// Back in the foreground: syncing uses the library again and sends what changed meanwhile, or, when it never
    /// started, tries again.
    func resumeCloudSync() {
        guard let librarySync else { return connectCloudSync() }
        Task {
            await librarySync.open()
            await librarySync.libraryChanged()
        }
    }

    private func connectCloudSync() {
        guard librarySync == nil, !isConnectingCloudSync, isInSharedLibrary, !isInBackground,
              let sharedLibrary, !LibrarySync.bundleContainer.isEmpty else { return }
        // A launch, a return to the foreground and an account change can all ask at once; one engine must result.
        isConnectingCloudSync = true
        Task {
            let started = await LibrarySync.start(app: .fieldGuide, fallback: sharedLibrary.folder)
            isConnectingCloudSync = false
            guard let started else { return }
            librarySync = started
            pictureFetcher = started
        }
    }
}
