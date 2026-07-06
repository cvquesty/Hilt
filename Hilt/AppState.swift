import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import HiltCore

/// Shared state for the main window and menu bar commands (HIG: menus must work).
@MainActor
final class AppState: ObservableObject {
    @Published var queue: [ModuleInfo] = []
    @Published var outputDirectory: URL?
    @Published var results: [ConversionResult] = []
    @Published var isRunning = false
    @Published var selection = Set<ModuleInfo.ID>()
    @Published var statusMessage = "Add or drop unlocked Windows e-Sword modules to begin."
    @Published var isDropTargeted = false
    @Published var showHelp = false
    @Published var helpTopicID: String = HelpTopic.welcome.id
    @Published var showOutputConfirm = false

    @Published var overwrite = true {
        didSet { UserDefaults.standard.set(overwrite, forKey: "hilt.overwrite") }
    }
    @Published var dryRun = false {
        didSet { UserDefaults.standard.set(dryRun, forKey: "hilt.dryRun") }
    }
    @Published var requireOutputFolder = false {
        didSet { UserDefaults.standard.set(requireOutputFolder, forKey: "hilt.requireOutputFolder") }
    }

    init() {
        let d = UserDefaults.standard
        if d.object(forKey: "hilt.overwrite") != nil {
            overwrite = d.bool(forKey: "hilt.overwrite")
        }
        if d.object(forKey: "hilt.dryRun") != nil {
            dryRun = d.bool(forKey: "hilt.dryRun")
        }
        if d.object(forKey: "hilt.requireOutputFolder") != nil {
            requireOutputFolder = d.bool(forKey: "hilt.requireOutputFolder")
        }
    }

    var readyCount: Int { queue.filter(\.isConvertible).count }
    var blockedCount: Int { queue.filter { !$0.isConvertible }.count }

    var outputPathDescription: String {
        if let outputDirectory {
            return outputDirectory.path
        }
        return "Not set — Convert will create a “hilt-output” folder next to each source file."
    }

    var hasChosenOutput: Bool { outputDirectory != nil }

    // MARK: - Panels

    func presentModuleOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.message = "Choose unlocked Windows e-Sword modules or a folder containing them"
        panel.prompt = "Add"
        panel.allowedContentTypes = Self.allowedTypes

        let finish: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK else { return }
            self?.addInputs(panel.urls)
        }

        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }

    func presentOutputFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose the folder where Hilt will write converted modules for e-Sword X"
        panel.prompt = "Select"

        let finish: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            _ = url.startAccessingSecurityScopedResource()
            self?.outputDirectory = url
            self?.statusMessage = "Output folder set. Converted files will be written here."
        }

        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }

    func clearQueue() {
        queue = []
        results = []
        selection = []
        statusMessage = "Queue cleared. Add or drop modules to begin again."
    }

    func revealOutput() {
        let dir = outputDirectory
            ?? results.compactMap(\.outputURL).first?.deletingLastPathComponent()
        guard let dir else { return }
        NSWorkspace.shared.open(dir)
    }

    func openHelp(topic: String = HelpTopic.welcome.id) {
        helpTopicID = topic
        showHelp = true
    }

    // MARK: - Queue

    func addInputs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        for url in urls {
            _ = url.startAccessingSecurityScopedResource()
        }

        let inspected = ModuleInspector.inspectInputs(urls, recursiveFolders: true)
        var byURL = Dictionary(uniqueKeysWithValues: queue.map { ($0.url, $0) })
        for info in inspected {
            byURL[info.url] = info
        }
        queue = byURL.values.sorted {
            $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending
        }

        let ready = readyCount
        let blocked = blockedCount
        if blocked == 0 {
            statusMessage = "\(ready) module\(ready == 1 ? "" : "s") ready. Choose an output folder, then Convert."
        } else {
            statusMessage = "\(ready) ready, \(blocked) cannot be converted — see Reason in the table."
        }
    }

    func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()

        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    var url: URL?
                    if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let u = item as? URL {
                        url = u
                    }
                    if let url {
                        lock.lock()
                        urls.append(url)
                        lock.unlock()
                    }
                }
            }
        }

        group.notify(queue: .main) { [weak self] in
            self?.addInputs(urls)
        }
        return handled
    }

    func requestConvert() {
        guard readyCount > 0, !isRunning else { return }
        if requireOutputFolder && outputDirectory == nil {
            showOutputConfirm = true
            return
        }
        if outputDirectory == nil {
            showOutputConfirm = true
            return
        }
        Task { await runConversion() }
    }

    func confirmDefaultOutputAndConvert() {
        showOutputConfirm = false
        Task { await runConversion() }
    }

    func runConversion() async {
        isRunning = true
        defer { isRunning = false }
        results = []

        let convertible = queue.filter(\.isConvertible)
        guard !convertible.isEmpty else {
            statusMessage = "Nothing ready to convert."
            return
        }

        let options = ConversionOptions(overwrite: overwrite, dryRun: dryRun, force: false)
        let converter = ModuleConverter(options: options)
        var collected: [ConversionResult] = []

        for item in queue where !item.isConvertible {
            collected.append(
                ConversionResult(
                    sourceURL: item.url,
                    moduleType: item.moduleType,
                    title: item.title,
                    abbreviation: item.abbreviation,
                    success: false,
                    message: "Skipped — \(item.statusLabel): \(item.detail)"
                )
            )
        }

        for item in convertible {
            let url = item.url
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            let out: URL
            if let outputDirectory {
                out = outputDirectory
            } else {
                out = url.deletingLastPathComponent().appendingPathComponent("hilt-output")
            }
            if outputDirectory == nil {
                outputDirectory = out
            }

            let outScoped = out.startAccessingSecurityScopedResource()
            defer { if outScoped { out.stopAccessingSecurityScopedResource() } }

            do {
                try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
                collected.append(try converter.convert(file: url, outputDirectory: out))
            } catch {
                collected.append(
                    ConversionResult(
                        sourceURL: url,
                        moduleType: item.moduleType,
                        title: item.title,
                        abbreviation: item.abbreviation,
                        success: false,
                        message: error.localizedDescription
                    )
                )
            }
        }

        results = collected.sorted {
            $0.sourceURL.lastPathComponent.localizedCaseInsensitiveCompare($1.sourceURL.lastPathComponent)
                == .orderedAscending
        }
        let ok = collected.filter(\.success).count
        let fail = collected.filter { !$0.success }.count
        if let dir = outputDirectory {
            statusMessage = "Finished: \(ok) succeeded, \(fail) failed/skipped. Output: \(dir.path)"
        } else {
            statusMessage = "Finished: \(ok) succeeded, \(fail) failed/skipped."
        }
    }

    static var allowedTypes: [UTType] {
        var types: [UTType] = [.item, .data, .folder, .content]
        for ext in ["bblx", "cmtx", "dctx", "topx", "bbli", "cmti", "dcti", "topi"] {
            if let t = UTType(filenameExtension: ext) {
                types.append(t)
            }
        }
        return types
    }
}
