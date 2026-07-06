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
    @Published var conversionProgress: String?
    @Published var selection = Set<ModuleInfo.ID>()
    @Published var statusMessage = "Add source modules, choose a destination folder, then Convert."
    @Published var isDropTargeted = false
    @Published var helpTopicID: String = HelpTopic.welcome.id
    @Published var showOutputConfirm = false

    /// Non-destructive default (HIG). UserDefaults preserves an explicit choice once set.
    @Published var overwrite = false {
        didSet { UserDefaults.standard.set(overwrite, forKey: "hilt.overwrite") }
    }
    @Published var dryRun = false {
        didSet { UserDefaults.standard.set(dryRun, forKey: "hilt.dryRun") }
    }

    init() {
        let d = UserDefaults.standard
        if d.object(forKey: "hilt.overwrite") != nil {
            overwrite = d.bool(forKey: "hilt.overwrite")
        }
        if d.object(forKey: "hilt.dryRun") != nil {
            dryRun = d.bool(forKey: "hilt.dryRun")
        }
    }

    var readyCount: Int { queue.filter(\.isConvertible).count }
    var blockedCount: Int { queue.filter { !$0.isConvertible }.count }

    /// Short path for the Destination control (never explains fallback policy here).
    var outputPathDescription: String {
        if let outputDirectory {
            return outputDirectory.path
        }
        return "No destination selected"
    }

    var hasChosenOutput: Bool { outputDirectory != nil }

    var selectedItems: [ModuleInfo] {
        queue.filter { selection.contains($0.id) }
    }

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

        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
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
        panel.prompt = "Choose"

        let finish: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            _ = url.startAccessingSecurityScopedResource()
            self?.outputDirectory = url
            self?.statusMessage = "Destination set. Converted files will be written only to this folder."
        }

        if let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible }) {
            panel.beginSheetModal(for: window, completionHandler: finish)
        } else {
            finish(panel.runModal())
        }
    }

    func clearQueue() {
        queue = []
        results = []
        selection = []
        conversionProgress = nil
        statusMessage = "Queue cleared. Add source modules to begin again."
    }

    func removeSelectedFromQueue() {
        guard !selection.isEmpty else { return }
        let removing = selection
        queue.removeAll { removing.contains($0.id) }
        selection = []
        results = []
        let ready = readyCount
        let blocked = blockedCount
        if queue.isEmpty {
            statusMessage = "Queue cleared. Add source modules to begin again."
        } else if blocked == 0 {
            statusMessage = "\(ready) module\(ready == 1 ? "" : "s") ready. Choose a destination, then Convert."
        } else {
            statusMessage = "\(ready) ready, \(blocked) cannot be converted — see Reason in the table."
        }
    }

    func revealOutput() {
        let dir = outputDirectory
            ?? results.compactMap(\.outputURL).first?.deletingLastPathComponent()
        guard let dir else { return }
        NSWorkspace.shared.open(dir)
    }

    func revealOriginalsInFinder() {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func copySelectedPaths() {
        let paths = selectedItems.map(\.url.path).joined(separator: "\n")
        guard !paths.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(paths, forType: .string)
        statusMessage = "Copied \(selectedItems.count) path\(selectedItems.count == 1 ? "" : "s") to the clipboard."
    }

    func openHelp(topic: String = HelpTopic.welcome.id) {
        helpTopicID = topic
        NotificationCenter.default.post(name: .hiltOpenHelp, object: topic)
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
            statusMessage = "\(ready) module\(ready == 1 ? "" : "s") ready. Choose a destination folder, then Convert."
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
        conversionProgress = nil
        defer {
            isRunning = false
            conversionProgress = nil
        }
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

        let total = convertible.count
        var index = 0
        for item in convertible {
            index += 1
            conversionProgress = "Converting \(index) of \(total)…"
            statusMessage = conversionProgress ?? statusMessage

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
        if dryRun {
            statusMessage = "Dry run finished: \(ok) would succeed, \(fail) failed/skipped. No files written."
        } else if let dir = outputDirectory {
            statusMessage =
                "Finished: \(ok) succeeded, \(fail) failed/skipped. Show in Finder, then e-Sword X → File → Resources → Import…"
            _ = dir
        } else {
            statusMessage = "Finished: \(ok) succeeded, \(fail) failed/skipped."
        }

        NSAccessibility.post(
            element: NSApp.mainWindow as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: statusMessage, .priority: NSAccessibilityPriorityLevel.medium.rawValue]
        )
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

extension Notification.Name {
    static let hiltOpenHelp = Notification.Name("org.questy.hilt.openHelp")
}
