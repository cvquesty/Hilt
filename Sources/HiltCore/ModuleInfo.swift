import Foundation

/// Snapshot of a module discovered for the convert queue (pre-conversion).
public struct ModuleInfo: Identifiable, Sendable, Equatable {
    public var id: URL { url }

    public var url: URL
    public var fileName: String
    public var moduleType: ModuleType
    public var fileSizeBytes: Int64

    /// Whether Hilt believes it can convert this module.
    public var isConvertible: Bool
    /// Short status for table (Ready / Unreadable / Unsupported …).
    public var statusLabel: String
    /// Human-readable reason when not convertible, or a brief readiness note.
    public var detail: String

    public var title: String?
    public var abbreviation: String?
    public var contentFormat: String?
    public var rowCount: Int?
    public var tables: [String]
    public var targetExtension: String

    public init(
        url: URL,
        fileName: String,
        moduleType: ModuleType,
        fileSizeBytes: Int64,
        isConvertible: Bool,
        statusLabel: String,
        detail: String,
        title: String? = nil,
        abbreviation: String? = nil,
        contentFormat: String? = nil,
        rowCount: Int? = nil,
        tables: [String] = [],
        targetExtension: String = ""
    ) {
        self.url = url
        self.fileName = fileName
        self.moduleType = moduleType
        self.fileSizeBytes = fileSizeBytes
        self.isConvertible = isConvertible
        self.statusLabel = statusLabel
        self.detail = detail
        self.title = title
        self.abbreviation = abbreviation
        self.contentFormat = contentFormat
        self.rowCount = rowCount
        self.tables = tables
        self.targetExtension = targetExtension
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSizeBytes, countStyle: .file)
    }

    public var typeDisplay: String {
        moduleType == .unknown ? "Unknown" : moduleType.displayName
    }
}

/// Reads module metadata without converting (for UI queue tables).
public enum ModuleInspector {
    /// Inspect a single file path (must exist).
    public static func inspect(url: URL) -> ModuleInfo {
        let fileName = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let type = ModuleType.from(fileExtension: ext)
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0

        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            return ModuleInfo(
                url: url,
                fileName: fileName,
                moduleType: .unknown,
                fileSizeBytes: size,
                isConvertible: true,
                statusLabel: "Folder",
                detail: "Folder will be scanned for convertible modules on Convert.",
                targetExtension: "—"
            )
        }

        if type == .unknown {
            return ModuleInfo(
                url: url,
                fileName: fileName,
                moduleType: type,
                fileSizeBytes: size,
                isConvertible: false,
                statusLabel: "Unsupported",
                detail: "Unrecognized extension “.\(ext.isEmpty ? "(none)" : ext)”. Expected .bblx, .cmtx, .dctx, .topx (Windows e-Sword modules).",
                targetExtension: ""
            )
        }

        if !type.isSupported {
            return ModuleInfo(
                url: url,
                fileName: fileName,
                moduleType: type,
                fileSizeBytes: size,
                isConvertible: false,
                statusLabel: "Not yet supported",
                detail: "\(type.displayName) modules (.\(type.windowsExtension)) are recognized but not implemented in this Hilt version yet.",
                targetExtension: type.macExtension
            )
        }

        // Probe SQLite
        do {
            let db = try SQLiteDatabase(path: url.path, readOnly: true)
            let tables = try db.tableNames()
            if tables.isEmpty {
                return ModuleInfo(
                    url: url,
                    fileName: fileName,
                    moduleType: type,
                    fileSizeBytes: size,
                    isConvertible: false,
                    statusLabel: "Unreadable",
                    detail: "SQLite opened but no tables are visible. This usually means the module is encrypted or not a valid e-Sword database.",
                    tables: tables,
                    targetExtension: type.macExtension
                )
            }

            let meta = try extractMetadata(type: type, db: db, tables: tables)
            let formatNote = meta.formatHint ?? "unknown markup"
            let rowsNote = meta.rowCount.map { "\($0) rows" } ?? "row count unknown"
            let titlePart = [meta.abbreviation, meta.title].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " — ")

            var detailParts: [String] = []
            if !titlePart.isEmpty { detailParts.append(titlePart) }
            detailParts.append(rowsNote)
            detailParts.append(formatNote)
            detailParts.append("→ .\(type.macExtension)")

            if let warning = meta.warning {
                return ModuleInfo(
                    url: url,
                    fileName: fileName,
                    moduleType: type,
                    fileSizeBytes: size,
                    isConvertible: false,
                    statusLabel: "Unreadable",
                    detail: warning,
                    title: meta.title,
                    abbreviation: meta.abbreviation,
                    contentFormat: meta.formatHint,
                    rowCount: meta.rowCount,
                    tables: tables,
                    targetExtension: type.macExtension
                )
            }

            return ModuleInfo(
                url: url,
                fileName: fileName,
                moduleType: type,
                fileSizeBytes: size,
                isConvertible: true,
                statusLabel: "Ready",
                detail: detailParts.joined(separator: " · "),
                title: meta.title,
                abbreviation: meta.abbreviation,
                contentFormat: meta.formatHint,
                rowCount: meta.rowCount,
                tables: tables,
                targetExtension: type.macExtension
            )
        } catch let e as ConversionError {
            return ModuleInfo(
                url: url,
                fileName: fileName,
                moduleType: type,
                fileSizeBytes: size,
                isConvertible: false,
                statusLabel: "Unreadable",
                detail: e.localizedDescription,
                targetExtension: type.macExtension
            )
        } catch {
            return ModuleInfo(
                url: url,
                fileName: fileName,
                moduleType: type,
                fileSizeBytes: size,
                isConvertible: false,
                statusLabel: "Unreadable",
                detail: "Could not open as SQLite: \(error.localizedDescription). Encrypted or corrupt modules cannot be converted.",
                targetExtension: type.macExtension
            )
        }
    }

    /// Expand folders into file inspections (one level or recursive).
    public static func inspectInputs(_ urls: [URL], recursiveFolders: Bool = true) -> [ModuleInfo] {
        var seen = Set<URL>()
        var out: [ModuleInfo] = []

        for url in urls {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else {
                out.append(
                    ModuleInfo(
                        url: url,
                        fileName: url.lastPathComponent,
                        moduleType: .unknown,
                        fileSizeBytes: 0,
                        isConvertible: false,
                        statusLabel: "Missing",
                        detail: "File not found at \(url.path)."
                    )
                )
                continue
            }

            if isDir.boolValue {
                let files = enumerateModuleFiles(in: url, recursive: recursiveFolders)
                if files.isEmpty {
                    out.append(
                        ModuleInfo(
                            url: url,
                            fileName: url.lastPathComponent + "/",
                            moduleType: .unknown,
                            fileSizeBytes: 0,
                            isConvertible: false,
                            statusLabel: "Empty folder",
                            detail: "No .bblx / .cmtx / .dctx / .topx modules found in this folder."
                        )
                    )
                } else {
                    for f in files where seen.insert(f).inserted {
                        out.append(inspect(url: f))
                    }
                }
            } else if seen.insert(url).inserted {
                out.append(inspect(url: url))
            }
        }
        return out
    }

    // MARK: - Internals

    private struct Extracted {
        var title: String?
        var abbreviation: String?
        var rowCount: Int?
        var formatHint: String?
        var warning: String?
    }

    private static func extractMetadata(type: ModuleType, db: SQLiteDatabase, tables: [String]) throws -> Extracted {
        var result = Extracted()

        if tables.contains(where: { $0.caseInsensitiveCompare("Details") == .orderedSame }) {
            if let desc = try? db.queryOptionalText("SELECT Description FROM Details LIMIT 1") {
                result.title = desc
            }
            if let abbr = try? db.queryOptionalText("SELECT Abbreviation FROM Details LIMIT 1") {
                result.abbreviation = abbr
            }
        }

        switch type {
        case .bible:
            guard tables.contains(where: { $0.caseInsensitiveCompare("Bible") == .orderedSame }) else {
                result.warning = "Expected table “Bible” is missing. Tables found: \(tables.joined(separator: ", ")). Not a standard Bible module layout."
                return result
            }
            result.rowCount = try? db.scalarInt("SELECT count(*) FROM Bible")
            if result.rowCount == 0 {
                result.warning = "Bible table is empty — nothing to convert."
            }
            result.formatHint = try sampleFormat(db: db, sql: "SELECT Scripture FROM Bible LIMIT 5")

        case .commentary:
            guard tables.contains(where: { $0.caseInsensitiveCompare("Commentary") == .orderedSame }) else {
                result.warning = "Expected table “Commentary” is missing. Tables found: \(tables.joined(separator: ", "))."
                return result
            }
            result.rowCount = try? db.scalarInt("SELECT count(*) FROM Commentary")
            if result.rowCount == 0 {
                result.warning = "Commentary table is empty — nothing to convert."
            }
            // Try common text columns for sample
            let cols = (try? db.columns(of: "Commentary")) ?? []
            if let textCol = ["Comments", "Commentary", "Content", "Scripture"].first(where: { c in
                cols.contains { $0.caseInsensitiveCompare(c) == .orderedSame }
            }) {
                result.formatHint = try sampleFormat(db: db, sql: "SELECT \"\(textCol)\" FROM Commentary LIMIT 5")
            } else {
                result.warning = "Commentary table has no recognized text column (Comments/Commentary/Content). Columns: \(cols.joined(separator: ", "))."
            }

        case .dictionary:
            let table = tables.first { $0.caseInsensitiveCompare("Dictionary") == .orderedSame }
            guard let table else {
                result.warning = "Expected table “Dictionary” is missing. Tables found: \(tables.joined(separator: ", "))."
                return result
            }
            result.rowCount = try? db.scalarInt("SELECT count(*) FROM \"\(table)\"")
            if result.rowCount == 0 {
                result.warning = "Dictionary table is empty — nothing to convert."
            }
            let cols = (try? db.columns(of: table)) ?? []
            if let defCol = ["Definition", "Description", "Content", "Data", "Notes"].first(where: { c in
                cols.contains { $0.caseInsensitiveCompare(c) == .orderedSame }
            }) {
                result.formatHint = try sampleFormat(db: db, sql: "SELECT \"\(defCol)\" FROM \"\(table)\" LIMIT 5")
            }

        case .topic:
            let table = tables.first { name in
                ["Topic", "Topics", "Notes"].contains { c in name.caseInsensitiveCompare(c) == .orderedSame }
            }
            guard let table else {
                result.warning = "Expected Topic/Notes table is missing. Tables found: \(tables.joined(separator: ", "))."
                return result
            }
            result.rowCount = try? db.scalarInt("SELECT count(*) FROM \"\(table)\"")
            if result.rowCount == 0 {
                result.warning = "Topic table is empty — nothing to convert."
            }
            let cols = (try? db.columns(of: table)) ?? []
            if let notesCol = ["Notes", "Note", "Content", "Data", "Text"].first(where: { c in
                cols.contains { $0.caseInsensitiveCompare(c) == .orderedSame }
            }) {
                result.formatHint = try sampleFormat(db: db, sql: "SELECT \"\(notesCol)\" FROM \"\(table)\" LIMIT 5")
            }

        default:
            break
        }

        return result
    }

    private static func sampleFormat(db: SQLiteDatabase, sql: String) throws -> String {
        let samples: [String] = try db.query(sql) { stmt in
            guard let c = sqlite3_column_text_bridge(stmt, 0) else { return "" }
            return String(cString: c)
        }.filter { !$0.isEmpty }

        if samples.isEmpty { return "no sample text" }

        var rtf = 0
        var html = 0
        var plain = 0
        for s in samples {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            let lower = t.lowercased()
            if lower.hasPrefix("{\\rtf") || t.contains("\\par") || t.contains("\\pard") {
                rtf += 1
            } else if lower.contains("<span") || lower.contains("<i>") || lower.contains("<b>")
                        || lower.contains("<br") || lower.contains("</") {
                html += 1
            } else {
                plain += 1
            }
        }

        if rtf > 0 && html == 0 { return "RTF text (will convert to HTML)" }
        if html > 0 && rtf == 0 { return "HTML text (passthrough)" }
        if rtf > 0 && html > 0 { return "Mixed RTF/HTML (will normalize)" }
        return "plain text"
    }

    private static func enumerateModuleFiles(in directory: URL, recursive: Bool) -> [URL] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: recursive ? [.skipsHiddenFiles] : [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
        ) else { return [] }

        let exts = Set(
            ModuleType.allCases.flatMap { [$0.windowsExtension, $0.macExtension] }
                .filter { !$0.isEmpty }
        )
        var files: [URL] = []
        for case let url as URL in enumerator {
            if exts.contains(url.pathExtension.lowercased()) {
                files.append(url)
            }
        }
        return files.sorted { $0.path.localizedCaseInsensitiveCompare($1.path) == .orderedAscending }
    }
}

import SQLite3

private func sqlite3_column_text_bridge(_ stmt: OpaquePointer, _ idx: Int32) -> UnsafePointer<UInt8>? {
    sqlite3_column_text(stmt, idx)
}
