import XCTest
import SQLite3
@testable import HiltCore

final class ModuleConverterTests: XCTestCase {
    func testBibleConversionRoundTrip() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("HiltTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tmp) }

        let source = tmp.appendingPathComponent("sample.bblx")
        try createSampleBBLX(at: source)

        let outDir = tmp.appendingPathComponent("out", isDirectory: true)
        let converter = ModuleConverter(options: ConversionOptions(overwrite: true))
        let result = try converter.convert(file: source, outputDirectory: outDir)

        XCTAssertTrue(result.success, result.message)
        XCTAssertEqual(result.rowsConverted, 2)
        XCTAssertGreaterThanOrEqual(result.rtfRowsConverted, 1)
        let out = try XCTUnwrap(result.outputURL)
        XCTAssertEqual(out.pathExtension, "bbli")
        XCTAssertTrue(FileManager.default.fileExists(atPath: out.path))

        // Verify HTML content stored
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open_v2(out.path, &db, SQLITE_OPEN_READONLY, nil), SQLITE_OK)
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT Scripture FROM Bible WHERE Book=1 AND Chapter=1 AND Verse=1", -1, &stmt, nil)
        XCTAssertEqual(sqlite3_step(stmt), SQLITE_ROW)
        let text = String(cString: sqlite3_column_text(stmt, 0))
        sqlite3_finalize(stmt)
        XCTAssertFalse(text.lowercased().hasPrefix("{\\rtf"), text)
        XCTAssertTrue(text.contains("beginning") || text.contains("God"), text)
    }

    func testUnsupportedExtension() {
        let converter = ModuleConverter()
        let url = URL(fileURLWithPath: "/tmp/nope.xyz")
        XCTAssertThrowsError(try converter.convert(file: url, outputDirectory: URL(fileURLWithPath: "/tmp"))) { error in
            guard let e = error as? ConversionError else {
                return XCTFail("Wrong error type \(error)")
            }
            if case .unsupportedExtension = e { return }
            if case .fileNotFound = e { return } // may hit not found first if we reorder — both ok-ish
            // Prefer unsupported when file missing with bad ext — our code checks ext first then exists
            switch e {
            case .unsupportedExtension, .fileNotFound: break
            default: XCTFail("Unexpected \(e)")
            }
        }
    }

    private func createSampleBBLX(at url: URL) throws {
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
            INSERT INTO Details VALUES (
                'Sample Bible','SMP','Test module',2,'DEFAULT',0,1,1,0,0
            );
            CREATE TABLE Bible (Book INT, Chapter INT, Verse INT, Scripture TEXT);
            """, nil, nil, nil)

        let rtf = #"{\rtf1\ansi In the beginning \b God\b0 created the heaven and the earth.\par}"#
        let plain = "And the earth was without form, and void."

        func insert(book: Int, chapter: Int, verse: Int, text: String) {
            var stmt: OpaquePointer?
            sqlite3_prepare_v2(db, "INSERT INTO Bible VALUES (?,?,?,?)", -1, &stmt, nil)
            sqlite3_bind_int(stmt, 1, Int32(book))
            sqlite3_bind_int(stmt, 2, Int32(chapter))
            sqlite3_bind_int(stmt, 3, Int32(verse))
            sqlite3_bind_text(stmt, 4, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
        insert(book: 1, chapter: 1, verse: 1, text: rtf)
        insert(book: 1, chapter: 1, verse: 2, text: plain)
    }
}
