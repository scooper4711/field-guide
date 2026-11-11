import SwiftUI
import Testing
@testable import FieldGuideUI

@Suite("Showing every column while no entry is chosen")
struct ColumnChoiceTests {
    @Test("A launch with nothing chosen shows every column; one that opens an entry leaves the layout to the system")
    func launch() {
        #expect(ColumnChoice(selection: nil).visibility == .all)
        #expect(ColumnChoice(selection: "entry").visibility == .automatic)
    }

    @Test("Choosing an entry hands the layout back to the system")
    func choosing() {
        var columns = ColumnChoice(selection: nil)
        columns.selectionChanged(to: "entry")
        #expect(columns.visibility == .automatic)
    }

    @Test("Clearing the entry shows every column again, and the next choice hands them back")
    func clearing() {
        var columns = ColumnChoice(selection: "entry")
        columns.visibility = .detailOnly
        columns.selectionChanged(to: nil)
        #expect(columns.visibility == .all)
        columns.selectionChanged(to: "another")
        #expect(columns.visibility == .automatic)
    }

    @Test("Every column the user showed stays shown when an entry is chosen")
    func usersChoice() {
        var columns = ColumnChoice(selection: "entry")
        columns.visibility = .all
        columns.selectionChanged(to: nil)
        columns.selectionChanged(to: "another")
        #expect(columns.visibility == .all)
    }

    @Test("Hiding columns with an entry open is left alone when another entry is chosen")
    func hidingWithAnEntry() {
        var columns = ColumnChoice(selection: nil)
        columns.selectionChanged(to: "entry")
        columns.visibility = .detailOnly
        columns.selectionChanged(to: "another")
        #expect(columns.visibility == .detailOnly)
    }
}
