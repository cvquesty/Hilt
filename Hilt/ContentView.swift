import AppKit
import SwiftUI
import UniformTypeIdentifiers
import HiltCore

struct ContentView: View {
    @State private var inputURLs: [URL] = []
    @State private var outputDirectory: URL?
    @State private var results: [ConversionResult] = []
    @State private var isRunning = false
    @State private var overwrite = true
    @State private var dryRun = false
    @State private var statusLine = "Drop Windows e-Sword modules here, or click Add…"

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            dropZone
            Divider()
            optionsBar
            Divider()
            resultsList
            Divider()
            footer
        }
        .frame(minWidth: 720, minHeight: 520)
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
        VStack(spacing: 12) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 36))
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
                    inputURLs = []
                    results = []
                    statusLine = "Drop Windows e-Sword modules here, or click Add…"
                }
                .disabled(inputURLs.isEmpty && results.isEmpty)
            }
            if !inputURLs.isEmpty {
                Text("\(inputURLs.count) item(s) queued")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(28)
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
                    .frame(maxWidth: 280, alignment: .trailing)
            }
            Button(isRunning ? "Converting…" : "Convert") {
                Task { await runConversion() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(inputURLs.isEmpty || isRunning)
        }
        .padding(12)
    }

    private var resultsList: some View {
        Group {
            if results.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("No results yet")
                        .font(.headline)
                    Text("Supported: .bblx .cmtx .dctx .topx → Mac *i modules")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(results.indices, id: \.self) { idx in
                    let r = results[idx]
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: r.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(r.success ? Color.green : Color.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.sourceURL.lastPathComponent)
                                .font(.body.weight(.semibold))
                            Text(r.message)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let out = r.outputURL, r.success {
                                Text(out.path)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .frame(maxHeight: .infinity)
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

    // MARK: - NSOpenPanel (reliable on macOS; dual .fileImporter is flaky)

    private func presentModuleOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.treatsFilePackagesAsDirectories = false
        panel.message = "Choose unlocked e-Sword modules or a folder of modules"
        panel.prompt = "Add"
        panel.allowedContentTypes = Self.allowedTypes

        // Present modally on the key window — works under App Sandbox.
        guard let window = NSApp.keyWindow ?? NSApp.windows.first else {
            // Fallback: runModal still works without an explicit parent.
            if panel.runModal() == .OK {
                addInputs(panel.urls)
            }
            return
        }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK else { return }
            addInputs(panel.urls)
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

        guard let window = NSApp.keyWindow ?? NSApp.windows.first else {
            if panel.runModal() == .OK, let url = panel.url {
                outputDirectory = url
                statusLine = "Output folder: \(url.path)"
            }
            return
        }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK, let url = panel.url else { return }
            outputDirectory = url
            statusLine = "Output folder: \(url.path)"
        }
    }

    // MARK: - Actions

    private func addInputs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        for url in urls where !inputURLs.contains(url) {
            // Keep security-scoped access for the life of the session item.
            _ = url.startAccessingSecurityScopedResource()
            inputURLs.append(url)
        }
        statusLine = "\(inputURLs.count) item(s) ready — choose output and Convert."
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    var url: URL?
                    if let data = item as? Data {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    } else if let u = item as? URL {
                        url = u
                    }
                    if let url {
                        DispatchQueue.main.async { addInputs([url]) }
                    }
                }
            }
        }
        return handled
    }

    @MainActor
    private func runConversion() async {
        isRunning = true
        defer { isRunning = false }
        results = []

        let options = ConversionOptions(overwrite: overwrite, dryRun: dryRun, force: false)
        let converter = ModuleConverter(options: options)

        var collected: [ConversionResult] = []
        for url in inputURLs {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }

            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

            let out: URL
            if let outputDirectory {
                out = outputDirectory
            } else if isDir.boolValue {
                out = url.appendingPathComponent("hilt-output")
            } else {
                out = url.deletingLastPathComponent().appendingPathComponent("hilt-output")
            }
            if outputDirectory == nil {
                outputDirectory = out
            }

            // Ensure output folder is accessible under sandbox when user-selected.
            let outScoped = out.startAccessingSecurityScopedResource()
            defer { if outScoped { out.stopAccessingSecurityScopedResource() } }

            if isDir.boolValue {
                collected.append(contentsOf: converter.convertDirectory(url, outputDirectory: out, recursive: true))
            } else {
                do {
                    collected.append(try converter.convert(file: url, outputDirectory: out))
                } catch {
                    collected.append(
                        ConversionResult(
                            sourceURL: url,
                            moduleType: ModuleType.from(fileExtension: url.pathExtension),
                            success: false,
                            message: error.localizedDescription
                        )
                    )
                }
            }
        }
        results = collected
        let ok = collected.filter(\.success).count
        let fail = collected.count - ok
        statusLine = "Finished: \(ok) succeeded, \(fail) failed."
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
