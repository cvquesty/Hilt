import Foundation
import SQLite3

/// Minimal SQLite helper (macOS system libsqlite3). No external deps.
final class SQLiteDatabase {
    private var db: OpaquePointer?

    init(path: String, readOnly: Bool) throws {
        let flags: Int32 = readOnly
            ? SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
            : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let rc = sqlite3_open_v2(path, &db, flags, nil)
        if rc != SQLITE_OK {
            let msg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let db { sqlite3_close(db) }
            throw ConversionError.databaseOpenFailed(msg)
        }
        // Fail fast on encrypted / non-SQLite payloads
        sqlite3_busy_timeout(db, 3000)
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    func tableNames() throws -> [String] {
        try query("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name") { stmt in
            String(cString: sqlite3_column_text(stmt, 0))
        }
    }

    func tableExists(_ name: String) throws -> Bool {
        try tableNames().contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    func columns(of table: String) throws -> [String] {
        // PRAGMA table_info cannot bind identifiers; validate name.
        guard table.range(of: #"^[A-Za-z0-9_]+$"#, options: .regularExpression) != nil else {
            throw ConversionError.internalError("Invalid table name: \(table)")
        }
        return try query("PRAGMA table_info(\(table))") { stmt in
            String(cString: sqlite3_column_text(stmt, 1))
        }
    }

    func scalarInt(_ sql: String) throws -> Int {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ConversionError.databaseOpenFailed(errmsg())
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(stmt, 0))
    }

    func execute(_ sql: String) throws {
        var err: UnsafeMutablePointer<CChar>?
        let rc = sqlite3_exec(db, sql, nil, nil, &err)
        if rc != SQLITE_OK {
            let msg = err.map { String(cString: $0) } ?? errmsg()
            if let err { sqlite3_free(err) }
            throw ConversionError.databaseWriteFailed(msg)
        }
    }

    func query<T>(_ sql: String, map: (OpaquePointer) throws -> T) throws -> [T] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ConversionError.databaseOpenFailed(errmsg())
        }
        var rows: [T] = []
        while true {
            let step = sqlite3_step(stmt)
            if step == SQLITE_ROW {
                rows.append(try map(stmt))
            } else if step == SQLITE_DONE {
                break
            } else {
                throw ConversionError.databaseOpenFailed(errmsg())
            }
        }
        return rows
    }

    func queryOptionalText(_ sql: String) throws -> String? {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw ConversionError.databaseOpenFailed(errmsg())
        }
        let step = sqlite3_step(stmt)
        if step == SQLITE_ROW {
            if let c = sqlite3_column_text(stmt, 0) {
                return String(cString: c)
            }
            return nil
        }
        return nil
    }

    /// Insert helper for text/int binds. `values` are Int or String.
    func insert(sql: String, binds: [Any?]) throws {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw ConversionError.databaseWriteFailed(errmsg())
        }
        for (i, value) in binds.enumerated() {
            let idx = Int32(i + 1)
            switch value {
            case nil:
                sqlite3_bind_null(stmt, idx)
            case let v as Int:
                sqlite3_bind_int64(stmt, idx, Int64(v))
            case let v as Int32:
                sqlite3_bind_int(stmt, idx, v)
            case let v as Int64:
                sqlite3_bind_int64(stmt, idx, v)
            case let v as Bool:
                sqlite3_bind_int(stmt, idx, v ? 1 : 0)
            case let v as String:
                sqlite3_bind_text(stmt, idx, v, -1, SQLITE_TRANSIENT)
            default:
                let s = String(describing: value!)
                sqlite3_bind_text(stmt, idx, s, -1, SQLITE_TRANSIENT)
            }
        }
        let step = sqlite3_step(stmt)
        if step != SQLITE_DONE {
            throw ConversionError.databaseWriteFailed(errmsg())
        }
    }

    func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE")
        do {
            try body()
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    private func errmsg() -> String {
        guard let db else { return "no database" }
        return String(cString: sqlite3_errmsg(db))
    }
}

/// SQLite wants a destructor pointer; -1 means "transient — copy now".
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
