import XCTest
import SQLite3
@testable import HiltCore

final class ModuleInspectorTests: XCTestCase {
    func testInspectReadyBible() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("HiltInspect-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let source = tmp.appendingPathComponent("ready.bblx")
        try writeSampleBible(at: source, empty: false)

        let info = ModuleInspector.inspect(url: source)
        XCTAssertTrue(info.isConvertible, info.detail)
        XCTAssertEqual(info.statusLabel, "Ready")
        XCTAssertEqual(info.moduleType, .bible)
        XCTAssertEqual(info.rowCount, 2)
        XCTAssertNotNil(info.contentFormat)
    }

    func testInspectUnsupportedExtension() {
        let url = URL(fileURLWithPath: "/tmp/notes.txt")
        let info = ModuleInspector.inspect(url: url)
        // file may not exist — either Missing path handling via inspectInputs, or unsupported ext
        XCTAssertFalse(info.isConvertible)
    }

    func testInspectEmptyBibleReportsReason() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("HiltInspect-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let source = tmp.appendingPathComponent("empty.bblx")
        try writeSampleBible(at: source, empty: true)

        let info = ModuleInspector.inspect(url: source)
        XCTAssertFalse(info.isConvertible)
        XCTAssertTrue(
            info.detail.localizedCaseInsensitiveContains("empty"),
            info.detail
        )
    }

    private func writeSampleBible(at url: URL, empty: Bool) throws {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else {
            throw ConversionError.databaseWriteFailed("open")
        }
        defer { sqlite3_close(db) }
        sqlite3_exec(db, """
            CREATE TABLE Details (
                Description NVARCHAR(250), Abbreviation NVARCHAR(50), Information TEXT,
                Version INT, Font NVARCHAR(50), RightToLeft BOOL, OT BOOL, NT BOOL,
                Apocrypha BOOL, Strong BOOL
            );
            INSERT INTO Details VALUES ('Inspect Bible','INS','Test',2,'DEFAULT',0,1,1,0,0);
            CREATE TABLE Bible (Book INT, Chapter INT, Verse INT, Scripture TEXT);
            """, nil, nil, nil)
        if !empty {
            let rtf = #"{\rtf1\ansi In the beginning \b God\b0 created.\par}"#
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, "INSERT INTO Bible VALUES (1,1,1,?)", -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, rtf, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
            sqlite3_prepare_v2(db, "INSERT INTO Bible VALUES (1,1,2,?)", -1, &stmt, nil)
            sqlite3_bind_text(stmt, 1, "And the earth was without form.", -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }
}
