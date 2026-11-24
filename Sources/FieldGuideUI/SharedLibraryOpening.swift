import CreatureArt
import Foundation
import SharedLibraries
import TablesideShared

/// What opening the libraries the Tableside apps share gave Field Guide at launch (shared libraries R1, R6).
struct SharedLibraryOpening {
    /// The art library: the shared one, or the app's own until it has moved in.
    var art: CreatureArtStore?
    /// The shared library, for its custom creatures and the art chosen for creatures; nil outside the group.
    var creatures: SharedLibrary?
    /// Why the app carries on with its own art library, or without one, to tell the user (R6.5).
    var failure: String?

    /// The app's own art library, used outside the App Group (R1.2) and until the move succeeds (R6.5).
    static func ownFolder() -> URL {
        URL.applicationSupportDirectory.appendingPathComponent("Field Guide/Creature Art")
    }

    /// Opens the shared library in the App Group and moves the app's own art library into it, once. A build
    /// outside the group (ad hoc, the tests) keeps its own. When the move fails the app keeps its own art library
    /// and still shows the shared custom creatures and chosen art; the next launch tries the move again.
    static func open(groupContainer: URL? = ToolkitGroup.containerURL(),
                     ownFolder: URL = ownFolder()) -> SharedLibraryOpening {
        guard let groupContainer else { return SharedLibraryOpening(art: try? CreatureArtStore(folder: ownFolder)) }
        let folder = groupContainer.appendingPathComponent(SharedLibrary.groupFolderName, isDirectory: true)
        let shared: SharedLibrary
        do {
            shared = try SharedLibrary(folder: folder, app: .fieldGuide)
        } catch {
            return keepingOwnArt(in: ownFolder, creatures: nil, after: error)
        }
        do {
            _ = try shared.moveIn(LibraryMove(app: .fieldGuide, artFolder: ownFolder))
        } catch {
            return keepingOwnArt(in: ownFolder, creatures: shared, after: error)
        }
        return openingSharedArt(in: folder, creatures: shared)
    }

    /// The shared art library, once the move has finished: the app's own has been retired, so there is no going
    /// back to it.
    private static func openingSharedArt(in folder: URL, creatures: SharedLibrary) -> SharedLibraryOpening {
        do {
            return SharedLibraryOpening(art: try CreatureArtStore(sharedLibraryIn: folder, app: .fieldGuide),
                                        creatures: creatures)
        } catch {
            return SharedLibraryOpening(creatures: creatures, failure: "Opening the shared art library failed, so "
                + "Field Guide shows no art from PDFs until it next launches: \(error.localizedDescription)")
        }
    }

    private static func keepingOwnArt(in ownFolder: URL, creatures: SharedLibrary?,
                                      after error: Error) -> SharedLibraryOpening {
        SharedLibraryOpening(
            art: try? CreatureArtStore(folder: ownFolder), creatures: creatures,
            failure: "Moving to the shared library failed, so Field Guide is using its own for now and will try "
                + "again next launch: \(error.localizedDescription)")
    }
}
