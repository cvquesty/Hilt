import SwiftUI

/// Non-modal Help window (Help → Hilt Help). Offline, navigable topics.
struct HelpView: View {
    @Binding var selectedTopicID: String

    private var selected: HelpTopic {
        HelpTopic.all.first { $0.id == selectedTopicID } ?? .welcome
    }

    var body: some View {
        NavigationSplitView {
            List(HelpTopic.all, selection: $selectedTopicID) { topic in
                Label(topic.title, systemImage: icon(for: topic.id))
                    .tag(topic.id)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
            .navigationTitle("Topics")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(selected.title)
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(selected.body)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: 640, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(selected.title)
        }
        .frame(minWidth: 720, minHeight: 460)
    }

    private func icon(for id: String) -> String {
        switch id {
        case HelpTopic.welcome.id: return "hand.wave"
        case HelpTopic.addModules.id: return "square.and.arrow.down"
        case HelpTopic.output.id: return "folder"
        case HelpTopic.queue.id: return "list.bullet"
        case HelpTopic.convert.id: return "arrow.triangle.2.circlepath"
        case HelpTopic.eswordX.id: return "book"
        case HelpTopic.limits.id: return "exclamationmark.triangle"
        case HelpTopic.keyboard.id: return "keyboard"
        default: return "questionmark.circle"
        }
    }
}
