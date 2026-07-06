import AppKit
import SwiftUI
import HiltCore

@main
struct HiltApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        // Single primary window (utility converter — avoid multi-window queue divergence).
        Window("Hilt", id: "main") {
            ContentView()
                .environmentObject(appState)
        }
        .defaultSize(width: 980, height: 700)
        .commands {
            HiltCommands(appState: appState)
        }

        // Non-modal Help window (not a sheet).
        Window("Hilt Help", id: "help") {
            HelpView(selectedTopicID: $appState.helpTopicID)
                .environmentObject(appState)
        }
        .defaultSize(width: 780, height: 520)

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        #endif
    }

}

/// Menu commands with access to `openWindow` (HIG: Help is a real window, not a sheet).
private struct HiltCommands: Commands {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // Application menu — About belongs here, not in Settings (HIG).
        CommandGroup(replacing: .appInfo) {
            Button("About Hilt") {
                showAboutPanel()
            }
        }

        // File menu
        CommandGroup(replacing: .newItem) {
            Button("Add Modules…") {
                appState.presentModuleOpenPanel()
            }
            .keyboardShortcut("o", modifiers: [.command])

            Button("Clear Queue") {
                appState.clearQueue()
            }
            .keyboardShortcut("k", modifiers: [.command])

            Button("Remove from Queue") {
                appState.removeSelectedFromQueue()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(appState.selection.isEmpty)

            Divider()

            Button("Output Folder…") {
                appState.presentOutputFolderPanel()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

            Button("Convert") {
                appState.requestConvert()
            }
            .keyboardShortcut(.return, modifiers: [.command])
            .disabled(appState.readyCount == 0 || appState.isRunning)

            Divider()

            Button("Show in Finder") {
                appState.revealOutput()
            }
            .disabled(!appState.hasChosenOutput && !appState.results.contains(where: \.success))
        }

        // Edit menu — selection actions
        CommandGroup(after: .pasteboard) {
            Button("Show Original in Finder") {
                appState.revealOriginalsInFinder()
            }
            .disabled(appState.selection.isEmpty)

            Button("Copy Path") {
                appState.copySelectedPaths()
            }
            .disabled(appState.selection.isEmpty)
        }

        // Help menu — primary item only; topics live in the Help window (HIG).
        CommandGroup(replacing: .help) {
            Button("Hilt Help") {
                appState.helpTopicID = HelpTopic.welcome.id
                openWindow(id: "help")
            }
            .keyboardShortcut("?", modifiers: [.command])

            Divider()

            Button("Hilt on GitHub…") {
                if let url = URL(string: "https://github.com/cvquesty/Hilt") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func showAboutPanel() {
        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "Hilt",
            .applicationVersion: HiltVersion.marketing,
            .version: HiltVersion.build,
            .credits: NSAttributedString(
                string: """
                \(HiltVersion.blurb)

                Converts unlocked Windows e-Sword modules for e-Sword X.
                Encrypted premium modules are refused.

                Not affiliated with e-Sword or Rick Meyers.
                Respect copyright on module content.

                Apache License 2.0
                """,
                attributes: [
                    .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        ]
        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
    }
}

#if os(macOS)
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Section("Conversion") {
                Toggle("Overwrite existing files in the destination folder", isOn: $state.overwrite)
                Toggle("Dry run (do not write files)", isOn: $state.dryRun)
            }
            Section("Destination") {
                LabeledContent("Current folder") {
                    Text(state.hasChosenOutput ? (state.outputDirectory?.path ?? "") : "Not set")
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .frame(maxWidth: 280, alignment: .trailing)
                }
                HStack {
                    Button("Choose Output Folder…") {
                        state.presentOutputFolderPanel()
                    }
                    if state.hasChosenOutput {
                        Button("Show in Finder") {
                            state.revealOutput()
                        }
                    }
                }
            }
            Section {
                Text("Overwrite and Dry run also apply from the next Convert. Overwrite never changes source modules.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 280)
        .padding(8)
    }
}
#endif
