import Foundation

public enum ConversionError: Error, LocalizedError, Equatable {
    case fileNotFound(URL)
    case unsupportedExtension(String)
    case unsupportedModuleType(ModuleType)
    case encryptedOrUnreadable(String)
    case missingTable(String)
    case databaseOpenFailed(String)
    case databaseWriteFailed(String)
    case emptyModule
    case outputExists(URL)
    case internalError(String)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.path)"
        case .unsupportedExtension(let ext):
            return "Unsupported file extension: .\(ext)"
        case .unsupportedModuleType(let type):
            return "Module type not yet supported: \(type.displayName) (.\(type.windowsExtension))"
        case .encryptedOrUnreadable(let detail):
            return "Module appears encrypted or unreadable. Hilt only converts unlocked modules. \(detail)"
        case .missingTable(let name):
            return "Expected SQLite table missing: \(name)"
        case .databaseOpenFailed(let detail):
            return "Could not open module database: \(detail)"
        case .databaseWriteFailed(let detail):
            return "Could not write converted module: \(detail)"
        case .emptyModule:
            return "Module contains no convertible content rows."
        case .outputExists(let url):
            return "Output already exists: \(url.path)"
        case .internalError(let detail):
            return detail
        }
    }
}
