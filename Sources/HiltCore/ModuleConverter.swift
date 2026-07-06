import Foundation

/// Converts unlocked Windows e-Sword modules (`.bblx`, `.cmtx`, …)
/// into e-Sword X / mobile-style modules (`.bbli`, `.cmti`, …).
///
/// Pure macOS — uses system SQLite only. Encrypted/premium modules are refused.
public struct ModuleConverter: Sendable {
    public var options: ConversionOptions

    public init(options: ConversionOptions = .default) {
        self.options = options
    }

    // MARK: - Public API

    public func convert(file source: URL, outputDirectory: URL) throws -> ConversionResult {
        let ext = source.pathExtension.lowercased()
        let type = ModuleType.from(fileExtension: ext)

        guard type != .unknown else {
            throw ConversionError.unsupportedExtension(ext)
        }
        guard type.isSupported else {
            throw ConversionError.unsupportedModuleType(type)
        }
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw ConversionError.fileNotFound(source)
        }

        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        let outName = source.deletingPathExtension().lastPathComponent + ".\(type.macExtension)"
        let outputURL = outputDirectory.appendingPathComponent(outName)

        if FileManager.default.fileExists(atPath: outputURL.path) && !options.overwrite && !options.dryRun {
            throw ConversionError.outputExists(outputURL)
        }

        // Probe readability / encryption
        try assertReadableSQLite(at: source)

        switch type {
        case .bible:
            return try convertBible(source: source, outputURL: outputURL)
        case .commentary:
            return try convertKeyedTextModule(
                source: source,
                outputURL: outputURL,
                type: .commentary,
                dataTable: "Commentary",
                textColumnCandidates: ["Comments", "Commentary", "Content", "Scripture"],
                keyColumns: ["Book", "Chapter", "Verse"]
            )
        case .dictionary:
            return try convertDictionary(source: source, outputURL: outputURL)
        case .topic:
            return try convertTopic(source: source, outputURL: outputURL)
        default:
            throw ConversionError.unsupportedModuleType(type)
        }
    }

    /// Convert every supported module found in a directory (non-recursive by default).
    public func convertDirectory(
        _ directory: URL,
        outputDirectory: URL,
        recursive: Bool = false
    ) -> [ConversionResult] {
        let files = enumerateModules(in: directory, recursive: recursive)
        return files.map { url in
            do {
                return try convert(file: url, outputDirectory: outputDirectory)
            } catch {
                return ConversionResult(
                    sourceURL: url,
                    moduleType: ModuleType.from(fileExtension: url.pathExtension),
                    success: false,
                    message: error.localizedDescription
                )
            }
        }
    }

    public func enumerateModules(in directory: URL, recursive: Bool) -> [URL] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: keys,
            options: recursive ? [.skipsHiddenFiles] : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return [] }

        var results: [URL] = []
        let supported = Set(ModuleType.allCases.filter(\.isSupported).map(\.windowsExtension))
        // Also accept already-mac extensions if user wants re-normalize (HTML pass)
        let macExts = Set(ModuleType.allCases.filter(\.isSupported).map(\.macExtension))

        for case let url as URL in enumerator {
            let ext = url.pathExtension.lowercased()
            if supported.contains(ext) || (options.force && macExts.contains(ext)) {
                results.append(url)
            }
        }
        return results.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }

    // MARK: - Bible

    private func convertBible(source: URL, outputURL: URL) throws -> ConversionResult {
        let src = try SQLiteDatabase(path: source.path, readOnly: true)
        guard try src.tableExists("Bible") else {
            throw ConversionError.missingTable("Bible")
        }
        guard try src.tableExists("Details") else {
            throw ConversionError.missingTable("Details")
        }

        let details = try readDetails(from: src)
        let verses: [(Int, Int, Int, String)] = try src.query(
            "SELECT Book, Chapter, Verse, Scripture FROM Bible ORDER BY Book, Chapter, Verse"
        ) { stmt in
            let book = Int(sqlite3_column_int64_s(stmt, 0))
            let chapter = Int(sqlite3_column_int64_s(stmt, 1))
            let verse = Int(sqlite3_column_int64_s(stmt, 2))
            let text = sqlite3_column_text_s(stmt, 3) ?? ""
            return (book, chapter, verse, text)
        }

        if verses.isEmpty { throw ConversionError.emptyModule }

        var rtfCount = 0
        let converted: [(Int, Int, Int, String)] = verses.map { book, chapter, verse, text in
            let wasRTF = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("{\\rtf")
                || text.contains("\\par")
            let html = RTFToHTML.convert(text)
            if wasRTF { rtfCount += 1 }
            return (book, chapter, verse, html)
        }

        if options.dryRun {
            return ConversionResult(
                sourceURL: source,
                outputURL: outputURL,
                moduleType: .bible,
                title: details.description,
                abbreviation: details.abbreviation,
                rowsConverted: converted.count,
                rtfRowsConverted: rtfCount,
                success: true,
                message: "Dry run — would write \(converted.count) verses (\(rtfCount) from RTF)"
            )
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let out = try SQLiteDatabase(path: outputURL.path, readOnly: false)
        try out.transaction {
            try out.execute("""
                CREATE TABLE Details (
                    Description NVARCHAR(255),
                    Abbreviation NVARCHAR(50),
                    Comments TEXT,
                    Version INT,
                    Font NVARCHAR(50),
                    RightToLeft BOOL,
                    OT BOOL,
                    NT BOOL,
                    Strong BOOL,
                    Language NVARCHAR(50)
                );
                """)
            // e-Sword X / mobile-style modules expect HTML content; Version 4 is the
            // community-documented HTML marker used by modern PC modules as well.
            try out.insert(
                sql: """
                    INSERT INTO Details (
                        Description, Abbreviation, Comments, Version, Font,
                        RightToLeft, OT, NT, Strong, Language
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                binds: [
                    details.description,
                    details.abbreviation,
                    details.information,
                    4,
                    details.font.isEmpty ? "DEFAULT" : details.font,
                    details.rightToLeft,
                    details.ot,
                    details.nt,
                    details.strong,
                    details.language
                ]
            )

            try out.execute("""
                CREATE TABLE Bible (
                    Book INT,
                    Chapter INT,
                    Verse INT,
                    Scripture TEXT
                );
                """)
            try out.execute(
                "CREATE INDEX BookChapterVerseIndex ON Bible (Book, Chapter, Verse);"
            )

            for (book, chapter, verse, html) in converted {
                try out.insert(
                    sql: "INSERT INTO Bible (Book, Chapter, Verse, Scripture) VALUES (?, ?, ?, ?)",
                    binds: [book, chapter, verse, html]
                )
            }
        }

        return ConversionResult(
            sourceURL: source,
            outputURL: outputURL,
            moduleType: .bible,
            title: details.description,
            abbreviation: details.abbreviation,
            rowsConverted: converted.count,
            rtfRowsConverted: rtfCount,
            success: true,
            message: "Converted \(converted.count) verses (\(rtfCount) RTF→HTML) → \(outputURL.lastPathComponent)"
        )
    }

    // MARK: - Commentary (Book/Chapter/Verse keyed)

    private func convertKeyedTextModule(
        source: URL,
        outputURL: URL,
        type: ModuleType,
        dataTable: String,
        textColumnCandidates: [String],
        keyColumns: [String]
    ) throws -> ConversionResult {
        let src = try SQLiteDatabase(path: source.path, readOnly: true)
        guard try src.tableExists(dataTable) else {
            throw ConversionError.missingTable(dataTable)
        }
        let cols = try src.columns(of: dataTable)
        guard let textCol = textColumnCandidates.first(where: { candidate in
            cols.contains { $0.caseInsensitiveCompare(candidate) == .orderedSame }
        }) else {
            throw ConversionError.internalError(
                "No text column among \(textColumnCandidates) in \(dataTable). Found: \(cols.joined(separator: ", "))"
            )
        }

        let details = (try? readDetails(from: src)) ?? DetailsInfo(
            description: source.deletingPathExtension().lastPathComponent,
            abbreviation: "",
            information: "",
            font: "DEFAULT",
            rightToLeft: false,
            ot: true,
            nt: true,
            strong: false,
            language: ""
        )

        // Build SELECT with available key columns
        let presentKeys = keyColumns.filter { key in
            cols.contains { $0.caseInsensitiveCompare(key) == .orderedSame }
        }
        let selectCols = (presentKeys + [textCol]).map { "\"\($0)\"" }.joined(separator: ", ")
        let order = presentKeys.isEmpty ? "" : " ORDER BY " + presentKeys.map { "\"\($0)\"" }.joined(separator: ", ")

        let rows: [[Any?]] = try src.query("SELECT \(selectCols) FROM \"\(dataTable)\"\(order)") { stmt in
            var values: [Any?] = []
            for i in 0..<presentKeys.count {
                values.append(Int(sqlite3_column_int64_s(stmt, Int32(i))))
            }
            values.append(sqlite3_column_text_s(stmt, Int32(presentKeys.count)) ?? "")
            return values
        }

        if rows.isEmpty { throw ConversionError.emptyModule }

        var rtfCount = 0
        let converted: [(keys: [Int], html: String)] = rows.map { row in
            let keys = row.dropLast().compactMap { $0 as? Int }
            let text = (row.last as? String) ?? ""
            let wasRTF = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("{\\rtf")
                || text.contains("\\par")
            if wasRTF { rtfCount += 1 }
            return (Array(keys), RTFToHTML.convert(text))
        }

        if options.dryRun {
            return ConversionResult(
                sourceURL: source,
                outputURL: outputURL,
                moduleType: type,
                title: details.description,
                abbreviation: details.abbreviation,
                rowsConverted: converted.count,
                rtfRowsConverted: rtfCount,
                success: true,
                message: "Dry run — would write \(converted.count) rows"
            )
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let out = try SQLiteDatabase(path: outputURL.path, readOnly: false)
        try out.transaction {
            try writeStandardDetails(to: out, details: details)

            let colDefs = presentKeys.map { "\($0) INT" } + ["\(textCol) TEXT"]
            try out.execute(
                "CREATE TABLE \(dataTable) (\(colDefs.joined(separator: ", ")));"
            )
            if presentKeys.count >= 2 {
                try out.execute(
                    "CREATE INDEX \(dataTable)KeyIndex ON \(dataTable) (\(presentKeys.joined(separator: ", ")));"
                )
            }

            let placeholders = Array(repeating: "?", count: presentKeys.count + 1).joined(separator: ", ")
            let insertCols = (presentKeys + [textCol]).joined(separator: ", ")
            for item in converted {
                var binds: [Any?] = item.keys.map { $0 as Any? }
                binds.append(item.html)
                try out.insert(
                    sql: "INSERT INTO \(dataTable) (\(insertCols)) VALUES (\(placeholders))",
                    binds: binds
                )
            }
        }

        return ConversionResult(
            sourceURL: source,
            outputURL: outputURL,
            moduleType: type,
            title: details.description,
            abbreviation: details.abbreviation,
            rowsConverted: converted.count,
            rtfRowsConverted: rtfCount,
            success: true,
            message: "Converted \(converted.count) rows (\(rtfCount) RTF→HTML) → \(outputURL.lastPathComponent)"
        )
    }

    // MARK: - Dictionary

    private func convertDictionary(source: URL, outputURL: URL) throws -> ConversionResult {
        let src = try SQLiteDatabase(path: source.path, readOnly: true)
        let table = try firstExistingTable(in: src, candidates: ["Dictionary", "dictionary"])
        let cols = try src.columns(of: table)

        let topicCol = firstColumn(in: cols, candidates: ["Topic", "Word", "Title", "Name"])
            ?? cols.first
        let defCol = firstColumn(in: cols, candidates: ["Definition", "Description", "Content", "Data", "Notes"])
            ?? cols.dropFirst().first

        guard let topicCol, let defCol else {
            throw ConversionError.internalError("Dictionary module missing topic/definition columns: \(cols)")
        }

        let details = (try? readDetails(from: src)) ?? DetailsInfo(
            description: source.deletingPathExtension().lastPathComponent,
            abbreviation: "",
            information: "",
            font: "DEFAULT",
            rightToLeft: false,
            ot: true,
            nt: true,
            strong: false,
            language: ""
        )

        let rows: [(String, String)] = try src.query(
            "SELECT \"\(topicCol)\", \"\(defCol)\" FROM \"\(table)\" ORDER BY \"\(topicCol)\""
        ) { stmt in
            (sqlite3_column_text_s(stmt, 0) ?? "", sqlite3_column_text_s(stmt, 1) ?? "")
        }

        if rows.isEmpty { throw ConversionError.emptyModule }

        var rtfCount = 0
        let converted: [(String, String)] = rows.map { topic, def in
            let wasRTF = def.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("{\\rtf")
                || def.contains("\\par")
            if wasRTF { rtfCount += 1 }
            return (topic, RTFToHTML.convert(def))
        }

        if options.dryRun {
            return ConversionResult(
                sourceURL: source,
                outputURL: outputURL,
                moduleType: .dictionary,
                title: details.description,
                abbreviation: details.abbreviation,
                rowsConverted: converted.count,
                rtfRowsConverted: rtfCount,
                success: true,
                message: "Dry run — would write \(converted.count) entries"
            )
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let out = try SQLiteDatabase(path: outputURL.path, readOnly: false)
        try out.transaction {
            try writeStandardDetails(to: out, details: details)
            try out.execute("""
                CREATE TABLE Dictionary (
                    Topic NVARCHAR(100),
                    Definition TEXT
                );
                """)
            try out.execute("CREATE INDEX TopicIndex ON Dictionary (Topic);")
            for (topic, def) in converted {
                try out.insert(
                    sql: "INSERT INTO Dictionary (Topic, Definition) VALUES (?, ?)",
                    binds: [topic, def]
                )
            }
        }

        return ConversionResult(
            sourceURL: source,
            outputURL: outputURL,
            moduleType: .dictionary,
            title: details.description,
            abbreviation: details.abbreviation,
            rowsConverted: converted.count,
            rtfRowsConverted: rtfCount,
            success: true,
            message: "Converted \(converted.count) entries (\(rtfCount) RTF→HTML) → \(outputURL.lastPathComponent)"
        )
    }

    // MARK: - Topic

    private func convertTopic(source: URL, outputURL: URL) throws -> ConversionResult {
        let src = try SQLiteDatabase(path: source.path, readOnly: true)
        let table = try firstExistingTable(in: src, candidates: ["Topic", "Topics", "Notes"])
        let cols = try src.columns(of: table)
        let titleCol = firstColumn(in: cols, candidates: ["Title", "Topic", "Name", "ID"]) ?? cols[0]
        let notesCol = firstColumn(in: cols, candidates: ["Notes", "Note", "Content", "Data", "Text"])
            ?? cols.dropFirst().first

        guard let notesCol else {
            throw ConversionError.internalError("Topic module missing notes column: \(cols)")
        }

        let details = (try? readDetails(from: src)) ?? DetailsInfo(
            description: source.deletingPathExtension().lastPathComponent,
            abbreviation: "",
            information: "",
            font: "DEFAULT",
            rightToLeft: false,
            ot: true,
            nt: true,
            strong: false,
            language: ""
        )

        let rows: [(String, String)] = try src.query(
            "SELECT \"\(titleCol)\", \"\(notesCol)\" FROM \"\(table)\""
        ) { stmt in
            (sqlite3_column_text_s(stmt, 0) ?? "", sqlite3_column_text_s(stmt, 1) ?? "")
        }

        if rows.isEmpty { throw ConversionError.emptyModule }

        var rtfCount = 0
        let converted: [(String, String)] = rows.map { title, notes in
            let wasRTF = notes.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("{\\rtf")
                || notes.contains("\\par")
            if wasRTF { rtfCount += 1 }
            return (title, RTFToHTML.convert(notes))
        }

        if options.dryRun {
            return ConversionResult(
                sourceURL: source,
                outputURL: outputURL,
                moduleType: .topic,
                title: details.description,
                rowsConverted: converted.count,
                rtfRowsConverted: rtfCount,
                success: true,
                message: "Dry run — would write \(converted.count) topics"
            )
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let out = try SQLiteDatabase(path: outputURL.path, readOnly: false)
        try out.transaction {
            try writeStandardDetails(to: out, details: details)
            try out.execute("""
                CREATE TABLE Topic (
                    Title NVARCHAR(100),
                    Notes TEXT
                );
                """)
            for (title, notes) in converted {
                try out.insert(
                    sql: "INSERT INTO Topic (Title, Notes) VALUES (?, ?)",
                    binds: [title, notes]
                )
            }
        }

        return ConversionResult(
            sourceURL: source,
            outputURL: outputURL,
            moduleType: .topic,
            title: details.description,
            rowsConverted: converted.count,
            rtfRowsConverted: rtfCount,
            success: true,
            message: "Converted \(converted.count) topics (\(rtfCount) RTF→HTML) → \(outputURL.lastPathComponent)"
        )
    }

    // MARK: - Details helpers

    private struct DetailsInfo {
        var description: String
        var abbreviation: String
        var information: String
        var font: String
        var rightToLeft: Bool
        var ot: Bool
        var nt: Bool
        var strong: Bool
        var language: String
    }

    private func readDetails(from db: SQLiteDatabase) throws -> DetailsInfo {
        // Flexible column read — modules vary slightly across authors/versions.
        let cols = try db.columns(of: "Details").map { $0.lowercased() }
        func has(_ name: String) -> Bool { cols.contains(name.lowercased()) }

        // Pull first row as raw strings via SELECT *
        let row: [String: String] = try {
            var map: [String: String] = [:]
            let names = try db.columns(of: "Details")
            let quoted = names.map { "\"\($0)\"" }.joined(separator: ", ")
            _ = try db.query("SELECT \(quoted) FROM Details LIMIT 1") { stmt in
                for (i, name) in names.enumerated() {
                    map[name.lowercased()] = sqlite3_column_text_s(stmt, Int32(i)) ?? ""
                }
                return 0
            }
            return map
        }()

        func val(_ keys: String...) -> String {
            for k in keys {
                if let v = row[k.lowercased()], !v.isEmpty { return v }
            }
            return ""
        }
        func flag(_ keys: String..., default def: Bool = false) -> Bool {
            for k in keys {
                if let v = row[k.lowercased()] {
                    if v == "1" || v.lowercased() == "true" { return true }
                    if v == "0" || v.lowercased() == "false" { return false }
                }
            }
            return def
        }

        _ = has // silence if unused in some builds
        return DetailsInfo(
            description: val("description", "title", "name"),
            abbreviation: val("abbreviation", "abbr"),
            information: val("information", "comments", "comment", "info"),
            font: val("font").isEmpty ? "DEFAULT" : val("font"),
            rightToLeft: flag("righttoleft", "rtl"),
            ot: flag("ot", default: true),
            nt: flag("nt", default: true),
            strong: flag("strong", "strongs"),
            language: val("language", "lang")
        )
    }

    private func writeStandardDetails(to db: SQLiteDatabase, details: DetailsInfo) throws {
        try db.execute("""
            CREATE TABLE Details (
                Description NVARCHAR(255),
                Abbreviation NVARCHAR(50),
                Comments TEXT,
                Version INT,
                Font NVARCHAR(50),
                Strong BOOL
            );
            """)
        try db.insert(
            sql: """
                INSERT INTO Details (Description, Abbreviation, Comments, Version, Font, Strong)
                VALUES (?, ?, ?, ?, ?, ?)
                """,
            binds: [
                details.description,
                details.abbreviation,
                details.information,
                4,
                details.font,
                details.strong
            ]
        )
    }

    private func firstExistingTable(in db: SQLiteDatabase, candidates: [String]) throws -> String {
        let names = try db.tableNames()
        for c in candidates {
            if let found = names.first(where: { $0.caseInsensitiveCompare(c) == .orderedSame }) {
                return found
            }
        }
        throw ConversionError.missingTable(candidates.joined(separator: " / "))
    }

    private func firstColumn(in cols: [String], candidates: [String]) -> String? {
        for c in candidates {
            if let found = cols.first(where: { $0.caseInsensitiveCompare(c) == .orderedSame }) {
                return found
            }
        }
        return nil
    }

    private func assertReadableSQLite(at url: URL) throws {
        // Encrypted modules often fail sqlite open or have zero tables.
        do {
            let db = try SQLiteDatabase(path: url.path, readOnly: true)
            let tables = try db.tableNames()
            if tables.isEmpty {
                throw ConversionError.encryptedOrUnreadable("No tables visible in SQLite file.")
            }
            // Probe a simple query
            _ = try db.scalarInt("SELECT count(*) FROM sqlite_master")
        } catch let e as ConversionError {
            throw e
        } catch {
            throw ConversionError.encryptedOrUnreadable(error.localizedDescription)
        }
    }
}

// MARK: - SQLite column helpers (C bridging without importing SQLite3 in every file)

import SQLite3

private func sqlite3_column_int64_s(_ stmt: OpaquePointer, _ idx: Int32) -> Int64 {
    sqlite3_column_int64(stmt, idx)
}

private func sqlite3_column_text_s(_ stmt: OpaquePointer, _ idx: Int32) -> String? {
    guard let c = sqlite3_column_text(stmt, idx) else { return nil }
    return String(cString: c)
}
