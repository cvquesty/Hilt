import SwiftUI
import HiltCore

@main
struct HiltApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

#if os(macOS)
struct SettingsView: View {
    var body: some View {
        Form {
            Text(HiltVersion.blurb)
                .font(.body)
            Text("Version \(HiltVersion.marketing) (\(HiltVersion.build))")
                .foregroundStyle(.secondary)
            Text("Unlocked modules only. Encrypted premium modules are refused.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 420)
    }
}
#endif
