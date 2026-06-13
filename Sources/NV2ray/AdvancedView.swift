import SwiftUI
import AppKit

struct AdvancedView: View {
    @EnvironmentObject private var store: AppStore
    @Binding var generatedConfig: String

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SettingsCard(
                    title: "Traffic protection",
                    subtitle: "Fail-closed routing for unexpected tunnel interruption"
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Kill switch", isOn: $store.configuration.tunnel.killSwitch)
                            .fontWeight(.semibold)

                        Text("Routes all network traffic through the Packet Tunnel, enables route enforcement and persistent On Demand reconnection. The sing-box TUN stack changes to gVisor while enabled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("Protected mode requires an IP address in the proxy server field and an IP-based encrypted DNS endpoint, for example https://1.1.1.1/dns-query. Domain-based servers can create a DNS bootstrap loop and are blocked while this mode is enabled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Toggle("Allow access to the local network", isOn: $store.configuration.tunnel.allowLocalNetwork)
                            .disabled(!store.configuration.tunnel.killSwitch)

                        Text("When disabled, local devices such as NAS, printers and other LAN hosts are not excluded from the protected route.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if store.connectionState == .connected {
                            Label("Reconnect the tunnel to apply changed protection settings.", systemImage: "arrow.clockwise")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                SettingsCard(title: "Generated sing-box configuration", subtitle: "Runtime configuration sent to the Packet Tunnel extension") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button("Generate") { generatedConfig = store.exportGeneratedConfig() }
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(generatedConfig, forType: .string)
                            }
                            Spacer()
                            Button("Save settings") { store.save() }
                        }
                        TextEditor(text: $generatedConfig)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 280)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }
}
