import SwiftUI
import HiltCore

@main
struct HiltApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
        .defaultSize(width: 980, height: 680)
        .commands {
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

                Button("Show Output in Finder") {
                    appState.revealOutput()
                }
                .disabled(!appState.hasChosenOutput && !appState.results.contains(where: \.success))
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Button("Hilt Help") {
                    appState.openHelp(topic: HelpTopic.welcome.id)
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])

                Button("Add Modules Help") {
                    appState.openHelp(topic: HelpTopic.addModules.id)
                }

                Button("Output Folder Help") {
                    appState.openHelp(topic: HelpTopic.output.id)
                }

                Button("Importing into e-Sword X") {
                    appState.openHelp(topic: HelpTopic.eswordX.id)
                }

                Divider()

                Button("Hilt on GitHub…") {
                    if let url = URL(string: "https://github.com/cvquesty/Hilt") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        #if os(macOS)
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        #endif
    }
}

#if os(macOS)
import AppKit

struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        TabView {
            Form {
                Section("Conversion") {
                    Toggle("Overwrite existing files in the output folder", isOn: $state.overwrite)
                    Toggle("Dry run by default (do not write files)", isOn: $state.dryRun)
                    Toggle("Always require an output folder before Convert", isOn: $state.requireOutputFolder)
                }
                Section("Output") {
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
                            Button("Reveal in Finder") {
                                state.revealOutput()
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .padding(8)
            .tabItem { Label("General", systemImage: "gearshape") }

            Form {
                Section {
                    Text(HiltVersion.blurb)
                    Text("Version \(HiltVersion.marketing) (\(HiltVersion.build))")
                        .foregroundStyle(.secondary)
                }
                Section("Important") {
                    Text("Hilt converts unlocked community modules only. Encrypted premium modules are refused. Not affiliated with e-Sword.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding(8)
            .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 480, height: 320)
    }
}
#endif
