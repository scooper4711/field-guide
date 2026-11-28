import FieldGuideKit
import Observation

/// Where the entry column is and has been, so Back works like a browser's: the chosen entry, the link it was opened
/// at, the pages followed from it, and each entry left for another, however it was left (a link's Open, the list,
/// Search Everything). Back steps back through the pages followed, then to the entries left.
@MainActor
@Observable
final class EntryNavigator {
    /// An entry as it was left: which, opened at which tab or heading, with which pages followed from it.
    struct Visit: Equatable {
        let id: String
        let root: PageLink?
        let path: [PageLink]
    }

    /// The chosen entry. Choosing another one, in the list or the search, leaves this one in the history.
    var selection: String? {
        didSet { selectionChanged(from: oldValue) }
    }

    /// The pages followed from the chosen entry, on its navigation stack.
    var path: [PageLink] = []
    /// The entries left, the most recent last.
    private(set) var history: [Visit] = []
    /// The link the chosen entry was opened at, when it names a tab or a heading.
    private var opened: PageLink?
    /// Set while the navigator moves on its own, so the move isn't recorded twice.
    private var isMoving = false

    init(selection: String?) {
        self.selection = selection
    }

    /// The link the chosen entry's page opens at; nil for its overview at the top.
    var root: PageLink? {
        opened?.entryID == selection ? opened : nil
    }

    var canGoBack: Bool {
        !path.isEmpty || !history.isEmpty
    }

    /// Shows a linked entry as if chosen in the sidebar, at the tab or heading the link names, leaving the current
    /// one in the history. False for a link that isn't to a listed entry, such as a trait's.
    func open(_ link: PageLink, in store: CatalogStore) -> Bool {
        guard let id = link.entryID else { return false }
        let current = currentVisit
        guard store.reveal(id) else { return false }
        if let current { history.append(current) }
        move(to: Visit(id: id, root: link, path: []))
        return true
    }

    /// Back one page followed, else to the entry left last, as it was.
    func goBack(in store: CatalogStore) {
        if !path.isEmpty {
            path.removeLast()
            return
        }
        guard let visit = history.popLast() else { return }
        _ = store.reveal(visit.id)
        move(to: visit)
    }

    /// Forgets the history, for a switch of system, whose entries the other system's lists don't hold.
    func forget() {
        history = []
    }

    private var currentVisit: Visit? {
        selection.map { Visit(id: $0, root: root, path: path) }
    }

    private func move(to visit: Visit) {
        isMoving = true
        opened = visit.root
        selection = visit.id
        path = visit.path
        isMoving = false
    }

    private func selectionChanged(from old: String?) {
        guard !isMoving, old != selection else { return }
        if let old { history.append(Visit(id: old, root: opened?.entryID == old ? opened : nil, path: path)) }
        opened = nil
        path = []
    }
}
