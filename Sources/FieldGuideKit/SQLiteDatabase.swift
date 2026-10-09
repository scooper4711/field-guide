import Foundation
import SQLite3

/// Why the catalog database failed.
public struct DatabaseError: Error, CustomStringConvertible, Equatable {
    public let operation: String
    public let message: String

    public var description: String { "\(operation) failed: \(message)" }
}

/// A small wrapper over SQLite: enough for the catalog's writer and reader.
public final class SQLiteDatabase {
    private var handle: OpaquePointer?

    /// Opens the database at `url`, read-only (as in the app bundle) or created for writing.
    public init(url: URL, readOnly: Bool) throws {
        let flags = readOnly ? SQLITE_OPEN_READONLY | SQLITE_OPEN_URI : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE
        // A bundled database never changes, so SQLite needn't look for journals beside it.
        let path = readOnly ? "file:\(url.path)?immutable=1" : url.path
        guard sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "no handle"
            sqlite3_close(handle)
            throw DatabaseError(operation: "Opening \(url.lastPathComponent)", message: message)
        }
    }

    deinit { sqlite3_close(handle) }

    /// Runs statements that return no rows.
    public func execute(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw error("Running SQL") }
    }

    /// Runs `sql` with `values` bound to its parameters, calling `row` for each result row.
    public func query(_ sql: String, _ values: [SQLiteValue] = [], row: (SQLiteRow) throws -> Void = { _ in }) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else { throw error("Preparing SQL") }
        defer { sqlite3_finalize(statement) }
        for (index, value) in values.enumerated() { value.bind(to: statement, at: Int32(index + 1)) }
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE { return }
            guard result == SQLITE_ROW else { throw error("Reading rows") }
            try row(SQLiteRow(statement: statement))
        }
    }

    private func error(_ operation: String) -> DatabaseError {
        DatabaseError(operation: operation, message: String(cString: sqlite3_errmsg(handle)))
    }
}

/// A value bound to a statement parameter.
public enum SQLiteValue {
    case text(String)
    case integer(Int)
    case null

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    func bind(to statement: OpaquePointer?, at index: Int32) {
        switch self {
        case let .text(value): sqlite3_bind_text(statement, index, value, -1, Self.transient)
        case let .integer(value): sqlite3_bind_int64(statement, index, Int64(value))
        case .null: sqlite3_bind_null(statement, index)
        }
    }
}

/// The current row of a query.
public struct SQLiteRow {
    let statement: OpaquePointer?

    public func text(_ column: Int32) -> String {
        sqlite3_column_text(statement, column).map { String(cString: $0) } ?? ""
    }

    /// The integer in `column`, or nil when it is NULL.
    public func integer(_ column: Int32) -> Int? {
        sqlite3_column_type(statement, column) == SQLITE_NULL ? nil : Int(sqlite3_column_int64(statement, column))
    }
}
