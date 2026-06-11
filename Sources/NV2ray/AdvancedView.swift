import SwiftUI
import AppKit

struct AdvancedView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var generatedConfig: String

    var body: some View {
        SettingsCard(title: "Generated sing-box configuration", subtitle: "Use this output when integrating the packet tunnel extension") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Generate") { generatedConfig = store.exportGeneratedConfig() }
                    Button("Copy") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(generatedConfig, forType: .string) }
                    Spacer()
                    Button("Save settings") { store.save() }
                }
                TextEditor(text: $generatedConfig)
                    .font(.system(.caption, design: .monospaced))
                    .frame(minHeight: 360)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

