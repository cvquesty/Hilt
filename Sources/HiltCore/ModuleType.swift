import Foundation

/// Known e-Sword Windows module types and their Mac / mobile counterparts.
public enum ModuleType: String, CaseIterable, Sendable {
    case bible
    case commentary
    case dictionary
    case topic
    case devotion
    case graphic
    case map
    case harmony
    case memory
    case overlay
    case unknown

    /// Windows (PC) file extension, lowercase without leading dot.
    public var windowsExtension: String {
        switch self {
        case .bible: return "bblx"
        case .commentary: return "cmtx"
        case .dictionary: return "dctx"
        case .topic: return "topx"
        case .devotion: return "devx"
        case .graphic: return "notx"
        case .map: return "mapx"
        case .harmony: return "harx"
        case .memory: return "memx"
        case .overlay: return "ovlx"
        case .unknown: return ""
        }
    }

    /// e-Sword X / HD / Android style extension (trailing `i`).
    public var macExtension: String {
        switch self {
        case .bible: return "bbli"
        case .commentary: return "cmti"
        case .dictionary: return "dcti"
        case .topic: return "topi"
        case .devotion: return "devi"
        case .graphic: return "noti"
        case .map: return "mapi"
        case .harmony: return "hari"
        case .memory: return "memi"
        case .overlay: return "ovli"
        case .unknown: return ""
        }
    }

    public var displayName: String {
        switch self {
        case .bible: return "Bible"
        case .commentary: return "Commentary"
        case .dictionary: return "Dictionary"
        case .topic: return "Topic Notes"
        case .devotion: return "Devotional"
        case .graphic: return "Graphics / Notes"
        case .map: return "Map"
        case .harmony: return "Harmony"
        case .memory: return "Memory Verses"
        case .overlay: return "Overlay"
        case .unknown: return "Unknown"
        }
    }

    /// Whether this type is implemented in the current MVP engine.
    public var isSupported: Bool {
        switch self {
        case .bible, .commentary, .dictionary, .topic:
            return true
        default:
            return false
        }
    }

    public static func from(fileExtension ext: String) -> ModuleType {
        let e = ext.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        switch e {
        case "bblx", "bbli", "bbl": return .bible
        case "cmtx", "cmti", "cmt": return .commentary
        case "dctx", "dcti", "dct": return .dictionary
        case "topx", "topi", "top": return .topic
        case "devx", "devi", "dev": return .devotion
        case "notx", "noti": return .graphic
        case "mapx", "mapi": return .map
        case "harx", "hari": return .harmony
        case "memx", "memi": return .memory
        case "ovlx", "ovli": return .overlay
        default: return .unknown
        }
    }
}
