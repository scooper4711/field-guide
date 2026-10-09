import Foundation
import Testing
@testable import FieldGuideKit

@Suite struct SQLiteDatabaseTests {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).sqlite")

    @Test func writesAndReadsTextIntegersAndNulls() throws {
        let database = try SQLiteDatabase(url: url, readOnly: false)
        try database.execute("CREATE TABLE t (a TEXT, b INTEGER)")
        try database.query("INSERT INTO t VALUES (?, ?)", [.text("x"), .integer(3)])
        try database.query("INSERT INTO t VALUES (?, ?)", [.text("y"), .null])
        var rows: [String] = []
        try SQLiteDatabase(url: url, readOnly: true).query("SELECT a, b FROM t ORDER BY a") {
            rows.append("\($0.text(0)) \($0.integer(1).map(String.init) ?? "nil")")
        }
        #expect(rows == ["x 3", "y nil"])
    }

    @Test func reportsWhatFailed() throws {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("missing/\(UUID()).sqlite")
        #expect(throws: DatabaseError.self) { try SQLiteDatabase(url: missing, readOnly: true) }
        let database = try SQLiteDatabase(url: url, readOnly: false)
        #expect(throws: DatabaseError.self) { try database.execute("NOT SQL") }
        #expect(throws: DatabaseError.self) { try database.query("SELECT * FROM nothing") }
        let error = DatabaseError(operation: "Reading rows", message: "busy")
        #expect(error.description == "Reading rows failed: busy")
    }

    @Test func facetsComeFromJSON() {
        #expect(Catalog.facets(fromJSON: #"{"rarity":["Rare"],"unknown":["x"]}"#) == [.rarity: ["Rare"]])
        #expect(Catalog.facets(fromJSON: "not json").isEmpty)
    }
}
