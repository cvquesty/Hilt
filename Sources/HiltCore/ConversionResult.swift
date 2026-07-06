import Foundation

public struct ConversionResult: Sendable, Equatable {
    public var sourceURL: URL
    public var outputURL: URL?
    public var moduleType: ModuleType
    public var title: String?
    public var abbreviation: String?
    public var rowsConverted: Int
    public var rtfRowsConverted: Int
    public var success: Bool
    public var message: String

    public init(
        sourceURL: URL,
        outputURL: URL? = nil,
        moduleType: ModuleType,
        title: String? = nil,
        abbreviation: String? = nil,
        rowsConverted: Int = 0,
        rtfRowsConverted: Int = 0,
        success: Bool,
        message: String
    ) {
        self.sourceURL = sourceURL
        self.outputURL = outputURL
        self.moduleType = moduleType
        self.title = title
        self.abbreviation = abbreviation
        self.rowsConverted = rowsConverted
        self.rtfRowsConverted = rtfRowsConverted
        self.success = success
        self.message = message
    }
}

public struct ConversionOptions: Sendable, Equatable {
    /// Overwrite existing output files.
    public var overwrite: Bool
    /// When true, only report what would happen.
    public var dryRun: Bool
    /// Force output even if source already looks like HTML mobile module.
    public var force: Bool

    public init(overwrite: Bool = false, dryRun: Bool = false, force: Bool = false) {
        self.overwrite = overwrite
        self.dryRun = dryRun
        self.force = force
    }

    public static let `default` = ConversionOptions()
}
