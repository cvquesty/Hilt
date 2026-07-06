import AppKit
import SwiftUI
import UniformTypeIdentifiers
import HiltCore

struct ContentView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            workflowCaption
            Divider()
            sourcesSection
            Divider()
            moduleTable
            Divider()
            destinationSection
            if !state.results.isEmpty {
                Divider()
                conversionResults
            }
            Divider()
            statusBar
        }
        .frame(minWidth: 900, minHeight: 620)
        .toolbar { toolbarContent }
        .navigationTitle("Hilt")
        .alert("No destination folder", isPresented: $state.showOutputConfirm) {
            Button("Choose Output Folder…") {
                state.showOutputConfirm = false
                state.presentOutputFolderPanel()
            }
            Button("Use Nearby hilt-output") {
                state.confirmDefaultOutputAndConvert()
            }
            Button("Cancel", role: .cancel) {
                state.showOutputConfirm = false
            }
        } message: {
            Text(
                "Choose a folder for all converted modules, or let Hilt create a “hilt-output” folder next to each source file. Source modules are never modified."
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .hiltOpenHelp)) { note in
            if let topic = note.object as? String {
                state.helpTopicID = topic
            }
            openWindow(id: "help")
        }
        .onDeleteCommand {
            state.removeSelectedFromQueue()
        }
    }

    // MARK: - Workflow caption

    private var workflowCaption: some View {
        HStack(spacing: 8) {
            workflowStep(number: 1, title: "Add sources", done: !state.queue.isEmpty)
            workflowChevron
            workflowStep(number: 2, title: "Choose destination", done: state.hasChosenOutput)
            workflowChevron
            workflowStep(number: 3, title: "Convert", done: state.results.contains(where: \.success))
            workflowChevron
            workflowStep(number: 4, title: "Import in e-Sword X", done: false)
            Spacer(minLength: 8)
            Button("Hilt Help") {
                state.openHelp()
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .help("Open Hilt Help (⌘?)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workflow: add sources, choose destination, convert, import in e-Sword X")
    }

    private var workflowChevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }

    private func workflowStep(number: Int, title: String, done: Bool) -> some View {
        HStack(spacing: 4) {
            Text("\(number)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(done ? Color.accentColor : Color.secondary)
                .frame(width: 16, height: 16)
                .background(
                    Circle()
                        .fill(done ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
                )
            Text(title)
                .font(.caption.weight(done ? .semibold : .regular))
                .foregroundStyle(done ? Color.primary : Color.secondary)
        }
        .accessibilityLabel("Step \(number): \(title)\(done ? ", complete" : "")")
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                state.presentModuleOpenPanel()
            } label: {
                Label("Add Modules…", systemImage: "plus")
            }
            .help("Add unlocked e-Sword modules or a folder (⌘O)")
            .accessibilityHint("Opens a panel to choose source module files or a folder")

            Button {
                state.clearQueue()
            } label: {
                Label("Clear Queue", systemImage: "trash")
            }
            .disabled(state.queue.isEmpty && state.results.isEmpty)
            .help("Remove all modules from the queue")

            if !state.selection.isEmpty {
                Button {
                    state.removeSelectedFromQueue()
                } label: {
                    Label("Remove", systemImage: "minus.circle")
                }
                .help("Remove selected modules from the queue (Delete)")
            }
        }

        ToolbarItem(placement: .confirmationAction) {
            Button {
                state.requestConvert()
            } label: {
                if state.isRunning {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(state.conversionProgress ?? "Converting…")
                    }
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
            .accessibilityHint("Writes converted modules to the destination folder only")
        }
    }

    // MARK: - Sources (input only — never writes output)

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("Sources", systemImage: "square.and.arrow.down")
                    .font(.headline)
                Text("Drop or add unlocked Windows modules here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Add Modules…") {
                    state.presentModuleOpenPanel()
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            dropZone
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        // Intentionally not a drop target for output — drops only on the well below.
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: state.isDropTargeted ? "square.and.arrow.down.fill" : "square.and.arrow.down")
                .font(.system(size: state.queue.isEmpty ? 36 : 22))
                .foregroundStyle(state.isDropTargeted ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)

            if state.queue.isEmpty {
                Text("Drop source modules here")
                    .font(.title3.weight(.semibold))
                Text("Unlocked Windows e-Sword files (.bblx, .cmtx, .dctx, .topx) or a folder of modules.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text("Your queue appears below after you add modules. Converted files go only to Destination — never onto these sources.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Button("How conversion works") {
                    state.openHelp(topic: HelpTopic.welcome.id)
                }
                .buttonStyle(.link)
                .font(.caption)
            } else {
                Text("Drop more source modules here, or use Add Modules…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, state.queue.isEmpty ? 28 : 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(state.isDropTargeted ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    state.isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                    style: StrokeStyle(lineWidth: state.isDropTargeted ? 2 : 1, dash: [7, 5])
                )
        )
        .onDrop(of: [.fileURL], isTargeted: $state.isDropTargeted) { providers in
            state.handleDrop(providers)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Source module drop zone")
        .accessibilityHint("Drop unlocked e-Sword module files or folders here to add them to the queue. Output is chosen separately under Destination.")
    }

    // MARK: - Modules table

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
                // Single empty state lives in Sources; keep table quiet.
                Text("Queue is empty — add source modules above.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 24)
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
                    .width(min: 140, ideal: 200)

                    TableColumn("Type") { item in
                        Text(item.typeDisplay)
                    }
                    .width(min: 80, ideal: 100, max: 120)

                    TableColumn("Title") { item in
                        Text(titleCell(item))
                            .lineLimit(1)
                    }
                    .width(min: 100, ideal: 160)

                    TableColumn("Reason") { item in
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(item.isConvertible ? Color.secondary : Color.primary)
                            .lineLimit(3)
                            .help(item.detail)
                    }
                    .width(min: 200, ideal: 320)
                }
                .contextMenu(forSelectionType: ModuleInfo.ID.self) { ids in
                    if !ids.isEmpty {
                        Button("Remove from Queue") {
                            state.selection = ids
                            state.removeSelectedFromQueue()
                        }
                        Button("Show Original in Finder") {
                            state.selection = ids
                            state.revealOriginalsInFinder()
                        }
                        Button("Copy Path") {
                            state.selection = ids
                            state.copySelectedPaths()
                        }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .frame(minHeight: 180)
    }

    // MARK: - Destination (output only — not a drop target)

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("Destination", systemImage: state.hasChosenOutput ? "folder.fill" : "folder.badge.questionmark")
                    .font(.headline)
                Text("Where converted files are written")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.hasChosenOutput ? "Save converted files to" : "No destination selected")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(state.hasChosenOutput ? Color.secondary : Color.orange)
                    Text(state.hasChosenOutput ? state.outputPathDescription : "Choose a folder before converting. Sources are not modified.")
                        .font(.body)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .foregroundStyle(state.hasChosenOutput ? Color.primary : Color.secondary)
                        .help(state.outputDirectory?.path ?? "No destination folder selected")
                        .accessibilityLabel("Destination folder")
                        .accessibilityValue(state.outputPathDescription)
                }

                Spacer(minLength: 8)

                Group {
                    if state.hasChosenOutput {
                        Button("Choose Output Folder…") {
                            state.presentOutputFolderPanel()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Choose Output Folder…") {
                            state.presentOutputFolderPanel()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .help("Pick where converted .bbli and related files are written")
                .accessibilityHint("Opens a folder panel for the conversion destination. This is not where you drop source modules.")

                if state.hasChosenOutput {
                    Button("Show in Finder") {
                        state.revealOutput()
                    }
                    .help("Show the destination folder in Finder")
                    .accessibilityLabel("Show output folder in Finder")
                }
            }

            Text("Sources are not modified. Converted files only go to the destination folder.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .controlBackgroundColor))
        // Do not attach onDrop here — Destination is never a drop target for modules.
    }

    // MARK: - Results & status

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
            .frame(maxHeight: 120)
        }
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            if state.isRunning {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Conversion in progress")
            }

            Text(state.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.updatesFrequently)

            Button("Help") {
                state.openHelp(topic: HelpTopic.eswordX.id)
            }
            .controlSize(.small)
            .buttonStyle(.borderless)
            .help("How to import into e-Sword X")

            if state.results.contains(where: \.success) || state.hasChosenOutput {
                Button("Show in Finder") {
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
        if item.isConvertible { return .green }
        if item.statusLabel == "Unreadable" { return .red }
        return .orange
    }

    private func titleCell(_ item: ModuleInfo) -> String {
        let parts = [item.abbreviation, item.title].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }
}
