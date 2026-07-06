import SwiftUI

/// In-app Help (Help → Hilt Help). Offline, navigable topics.
struct HelpView: View {
    @Binding var selectedTopicID: String

    private var selected: HelpTopic {
        HelpTopic.all.first { $0.id == selectedTopicID } ?? .welcome
    }

    var body: some View {
        NavigationSplitView {
            List(HelpTopic.all, selection: $selectedTopicID) { topic in
                Text(topic.title)
                    .tag(topic.id)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            .navigationTitle("Hilt Help")
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text(selected.title)
                        .font(.title2.weight(.semibold))
                    Text(selected.body)
                        .font(.body)
                        .textSelection(.enabled)
                        .frame(maxWidth: 560, alignment: .leading)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(selected.title)
        }
        .frame(minWidth: 640, minHeight: 420)
    }
}
