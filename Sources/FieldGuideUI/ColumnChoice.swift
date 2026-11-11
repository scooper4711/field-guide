import SwiftUI

/// Which of the split view's columns show: every one while no entry is chosen, so there is always something to
/// choose from (an iPad in portrait otherwise shows only the empty entry column); once one is chosen, the system's
/// layout again, unless the user had shown every column themselves.
struct ColumnChoice: Equatable {
    var visibility: NavigationSplitViewVisibility
    /// Whether no entry being chosen is what showed every column, so choosing one hands the layout back.
    private var showedForNoEntry: Bool

    init(selection: String?) {
        visibility = selection == nil ? .all : .automatic
        showedForNoEntry = selection == nil
    }

    mutating func selectionChanged(to selection: String?) {
        if selection == nil {
            showedForNoEntry = visibility != .all
            visibility = .all
        } else if showedForNoEntry {
            visibility = .automatic
            showedForNoEntry = false
        }
    }
}
