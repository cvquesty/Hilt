import AppKit
import SwiftUI
import UniformTypeIdentifiers
import HiltCore

struct ContentView: View {
    /// Inspected modules shown in the queue table (files expanded from folders).
    @State private var queue: [ModuleInfo] = []
    @State private var outputDirectory: URL?
    @State private var results: [ConversionResult] = []
    @State private var isRunning = false
    @State private var overwrite = true
    @State private var dryRun = false
    @State private var statusLine = "Drop Windows e-Sword modules here, or click Add…"
    @State private var selection = Set<ModuleInfo.ID>()

    private var readyCount: Int { queue.filter(\.isConvertible).count }
    private var blockedCount: Int { queue.filter { !$0.isConvertible }.count }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            dropZone
            Divider()
            optionsBar
            Divider()
            moduleTable
            if !results.isEmpty {
                Divider()
                conversionResults
            }
            Divider()
            footer
        }
        .frame(minWidth: 860, minHeight: 580)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Hilt")
                    .font(.title2.weight(.bold))
                Text("Mac-native conversion for e-Sword X")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("v\(HiltVersion.marketing)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            Text(statusLine)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack {
                Button("Add Modules…") {
                    presentModuleOpenPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])
                Button("Clear List") {
                    queue = []
                    results = []
                    selection = []
                    statusLine = "Drop Windows e-Sword modules here, or click Add…"
                }
                .disabled(queue.isEmpty && results.isEmpty)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(Color.gray.opacity(0.06))
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            handleDrop(providers)
        }
    }

    private var optionsBar: some View {
        HStack(spacing: 16) {
            Toggle("Overwrite existing", isOn: $overwrite)
            Toggle("Dry run", isOn: $dryRun)
            Spacer()
            Button("Output Folder…") {
                presentOutputFolderPanel()
            }
            if let outputDirectory {
                Text(outputDirectory.path)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 240, alignment: .trailing)
            }
            Button(isRunning ? "Converting…" : "Convert Ready") {
                Task { await runConversion() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(readyCount == 0 || isRunning)
        }
        .padding(12)
    }

    /// Primary table: every added/dropped module with inspect status.
    private var moduleTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Modules")
                    .font(.headline)
                Spacer()
                if !queue.isEmpty {
                    Text("\(readyCount) ready · \(blockedCount) blocked · \(queue.count) total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if queue.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tablecells")
                        .font(.system(size: 36))
                        .foregroundStyle(.secondary)
                    Text("No modules in the queue")
                        .font(.headline)
                    Text("Add or drop .bblx / .cmtx / .dctx / .topx files. Each row shows type, size, and whether Hilt can read it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(queue, selection: $selection) {
                    TableColumn("Status") { item in
                        HStack(spacing: 6) {
                            Image(systemName: statusIcon(item))
                                .foregroundStyle(statusColor(item))
                            Text(item.statusLabel)
                                .font(.caption.weight(.semibold))
                        }
                    }
                    .width(min: 100, ideal: 110, max: 130)

                    TableColumn("File") { item in
                        Text(item.fileName)
                            .lineLimit(1)
                            .help(item.url.path)
                    }
                    .width(min: 120, ideal: 180)

                    TableColumn("Type") { item in
                        Text(item.typeDisplay)
                    }
                    .width(min: 80, ideal: 100, max: 120)

                    TableColumn("Size") { item in
                        Text(item.formattedSize)
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 60, ideal: 70, max: 90)

                    TableColumn("Title / Abbr") { item in
                        Text(titleCell(item))
                            .lineLimit(1)
                    }
                    .width(min: 100, ideal: 140)

                    TableColumn("Rows") { item in
                        Text(item.rowCount.map(String.init) ?? "—")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 50, ideal: 60, max: 70)

                    TableColumn("Format") { item in
                        Text(item.contentFormat ?? "—")
                            .lineLimit(1)
                    }
                    .width(min: 100, ideal: 150)

                    TableColumn("Target") { item in
                        Text(item.targetExtension.isEmpty ? "—" : ".\(item.targetExtension)")
                            .font(.system(.caption, design: .monospaced))
                    }
                    .width(min: 50, ideal: 60, max: 70)

                    TableColumn("Details / reason") { item in
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(item.isConvertible ? Color.secondary : Color.primary)
                            .lineLimit(3)
                            .help(item.detail)
                    }
                    .width(min: 180, ideal: 280)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(minHeight: 220)
    }

    private var conversionResults: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last conversion")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            List(results.indices, id: \.self) { idx in
                let r = results[idx]
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: r.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(r.success ? Color.green : Color.red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.sourceURL.lastPathComponent)
                            .font(.body.weight(.semibold))
                        Text(r.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxHeight: 140)
        }
    }

    private var footer: some View {
        HStack {
            Text("Unlocked modules only · Import in e-Sword X via File → Resources → Import…")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if results.contains(where: \.success),
               let dir = outputDirectory
                ?? results.compactMap(\.outputURL).first?.deletingLastPathComponent() {
                Button("Reveal Output") {
                    NSWorkspace.shared.open(dir)
                }
            }
        }
        .padding(12)
    }

    // MARK: - Table helpers

    private func statusIcon(_ item: ModuleInfo) -> String {
        if item.isConvertible { return "checkmark.circle.fill" }
        switch item.statusLabel {
        case "Unsupported", "Not yet supported": return "questionmark.circle.fill"
        case "Missing", "Empty folder": return "tray.fill"
        default: return "xmark.octagon.fill"
        }
    }

    private func statusColor(_ item: ModuleInfo) -> Color {
        item.isConvertible ? .green : .orange
    }

    private func titleCell(_ item: ModuleInfo) -> String {
        let parts = [item.abbreviation, item.title].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    // MARK: - NSOpenPanel

    private func presentModuleOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.message = "Choose unlocked e-Sword modules or a folder of modules"
        panel.prompt = "Add"
        panel.allowedContentTypes = Self.allowedTypes

        let present: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK else { return }
            addInputs(panel.urls)
        }

        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            panel.beginSheetModal(for: window, completionHandler: present)
        } else {
            present(panel.runModal())
        }
    }

    private func presentOutputFolderPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = "Choose a folder for converted modules"
        panel.prompt = "Select"

        let present: (NSApplication.ModalResponse) -> Void = { response in
            guard response == .OK, let url = panel.url else { return }
            _ = url.startAccessingSecurityScopedResource()
            outputDirectory = url
            statusLine = "Output folder: \(url.path)"
        }

        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            panel.beginSheetModal(for: window, completionHandler: present)
        } else {
            present(panel.runModal())
        }
    }

    // MARK: - Queue

    private func addInputs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        for url in urls {
            _ = url.startAccessingSecurityScopedResource()
        }

        let inspected = ModuleInspector.inspectInputs(urls, recursiveFolders: true)
        // Merge by URL; replace existing rows for the same file.
        var byURL = Dictionary(uniqueKeysWithValues: queue.map { ($0.url, $0) })
        for info in inspected {
            byURL[info.url] = info
        }
        queue = byURL.values.sorted {
            $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending
        }

        let ready = queue.filter(\.isConvertible).count
        let blocked = queue.filter { !$0.isConvertible }.count
        if blocked == 0 {
            statusLine = "\(ready) module(s) ready to convert."
        } else {
            statusLine = "\(ready) ready, \(blocked) cannot be converted — see Details / reason."
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
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

        group.notify(queue: .main) {
            addInputs(urls)
        }
        return handled
    }

    @MainActor
    private func runConversion() async {
        isRunning = true
        defer { isRunning = false }
        results = []

        let convertible = queue.filter(\.isConvertible)
        guard !convertible.isEmpty else {
            statusLine = "Nothing ready to convert."
            return
        }

        let options = ConversionOptions(overwrite: overwrite, dryRun: dryRun, force: false)
        let converter = ModuleConverter(options: options)
        var collected: [ConversionResult] = []

        // Also record blocked items as skipped with their inspect reason.
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

        // Re-inspect after convert so table still reflects source state.
        results = collected.sorted {
            $0.sourceURL.lastPathComponent.localizedCaseInsensitiveCompare($1.sourceURL.lastPathComponent)
                == .orderedAscending
        }
        let ok = collected.filter(\.success).count
        let fail = collected.filter { !$0.success }.count
        statusLine = "Finished: \(ok) succeeded, \(fail) failed/skipped."
    }

    private static var allowedTypes: [UTType] {
        var types: [UTType] = [.item, .data, .folder, .content]
        for ext in ["bblx", "cmtx", "dctx", "topx", "bbli", "cmti", "dcti", "topi"] {
            if let t = UTType(filenameExtension: ext) {
                types.append(t)
            }
        }
        return types
    }
}
