import AppKit
import SwiftUI
import UniformTypeIdentifiers
import HiltCore

struct ContentView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 0) {
            outputBanner
            Divider()
            dropZone
            Divider()
            moduleTable
            if !state.results.isEmpty {
                Divider()
                conversionResults
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 900, minHeight: 600)
        .toolbar { toolbarContent }
        .navigationTitle("Hilt")
        .sheet(isPresented: $state.showHelp) {
            HelpView(selectedTopicID: $state.helpTopicID)
                .frame(minWidth: 700, minHeight: 460)
        }
        .alert("Output folder not set", isPresented: $state.showOutputConfirm) {
            Button("Choose Folder…") {
                state.showOutputConfirm = false
                state.presentOutputFolderPanel()
            }
            Button("Use hilt-output beside sources") {
                state.confirmDefaultOutputAndConvert()
            }
            Button("Cancel", role: .cancel) {
                state.showOutputConfirm = false
            }
        } message: {
            Text("Choose a folder for all converted modules, or let Hilt create a “hilt-output” folder next to each source file.")
        }
    }

    // MARK: - Toolbar (HIG: primary actions in chrome, not a fake header)

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                state.presentModuleOpenPanel()
            } label: {
                Label("Add Modules…", systemImage: "plus")
            }
            .help("Add unlocked e-Sword modules or a folder (⌘O)")
            .accessibilityHint("Opens a panel to choose module files or a folder")

            Button("Clear") {
                state.clearQueue()
            }
            .disabled(state.queue.isEmpty && state.results.isEmpty)
            .help("Remove all modules from the queue")
        }

        ToolbarItemGroup(placement: .automatic) {
            Toggle("Overwrite", isOn: $state.overwrite)
                .help("Replace existing files with the same name in the output folder")
            Toggle("Dry run", isOn: $state.dryRun)
                .help("Report what would be written without creating files")
        }

        ToolbarItem(placement: .confirmationAction) {
            Button {
                state.requestConvert()
            } label: {
                if state.isRunning {
                    Text("Converting…")
                } else if state.readyCount > 0 {
                    Text("Convert \(state.readyCount)")
                } else {
                    Text("Convert")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(state.readyCount == 0 || state.isRunning)
            .help("Convert ready modules to e-Sword X format (⌘↩)")
            .accessibilityHint("Writes converted modules to the output folder")
        }
    }

    // MARK: - Output banner (always visible)

    private var outputBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "folder")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Output folder")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(state.outputPathDescription)
                    .font(.system(.body, design: .default))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .help(state.outputDirectory?.path ?? state.outputPathDescription)
                    .accessibilityLabel("Output folder")
                    .accessibilityValue(state.outputPathDescription)
            }

            Spacer(minLength: 8)

            Button("Choose Output Folder…") {
                state.presentOutputFolderPanel()
            }
            .help("Pick where converted .bbli and related files are written")

            if state.hasChosenOutput {
                Button("Reveal") {
                    state.revealOutput()
                }
                .help("Show the output folder in Finder")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Drop zone

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: state.queue.isEmpty ? 36 : 22))
                .foregroundStyle(state.isDropTargeted ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)

            if state.queue.isEmpty {
                Text("Drop modules here")
                    .font(.title3.weight(.semibold))
                Text("Unlocked Windows e-Sword files (.bblx, .cmtx, .dctx, .topx) or a folder of modules.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Converted files are written to the output folder above — not back onto your originals.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            } else {
                Text("Drop more modules here, or use Add Modules…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, state.queue.isEmpty ? 28 : 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(state.isDropTargeted ? Color.accentColor.opacity(0.08) : Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    state.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: state.isDropTargeted ? 2 : 1, dash: [7, 5])
                )
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .onDrop(of: [.fileURL], isTargeted: $state.isDropTargeted) { providers in
            state.handleDrop(providers)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Module drop zone")
        .accessibilityHint("Drop e-Sword module files or folders here to add them to the queue")
    }

    // MARK: - Table

    private var moduleTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Modules")
                    .font(.headline)
                Spacer()
                if !state.queue.isEmpty {
                    Text("\(state.readyCount) ready · \(state.blockedCount) blocked · \(state.queue.count) total")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            if state.queue.isEmpty {
                VStack(spacing: 8) {
                    Text("No modules in the queue yet")
                        .font(.headline)
                    Text("Use the drop area above or choose Add Modules… Each row will show whether Hilt can convert the file and why if it cannot.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(state.queue, selection: $state.selection) {
                    TableColumn("Status") { item in
                        HStack(spacing: 6) {
                            Image(systemName: statusIcon(item))
                                .foregroundStyle(statusColor(item))
                                .accessibilityHidden(true)
                            Text(item.statusLabel)
                                .font(.caption.weight(.semibold))
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(item.statusLabel)
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

                    TableColumn("Title") { item in
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

                    TableColumn("Reason") { item in
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
        .frame(minHeight: 200)
    }

    private var conversionResults: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last conversion")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 8)
            List(state.results.indices, id: \.self) { idx in
                let r = state.results[idx]
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: r.success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .foregroundStyle(r.success ? Color.green : Color.red)
                        .accessibilityLabel(r.success ? "Succeeded" : "Failed")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.sourceURL.lastPathComponent)
                            .font(.body.weight(.semibold))
                        Text(r.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(maxHeight: 140)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            Text(state.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Unlocked modules only · After convert: e-Sword X → File → Resources → Import…")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            if state.results.contains(where: \.success) || state.hasChosenOutput {
                Button("Reveal in Finder") {
                    state.revealOutput()
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Helpers

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
}
