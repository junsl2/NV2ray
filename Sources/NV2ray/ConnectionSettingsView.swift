import SwiftUI

struct ConnectionSettingsView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        SettingsCard(title: "VLESS connection", subtitle: "Reality, TLS and transport options") {
            Form {
                TextField("Profile name", text: $store.configuration.profile.name)
                TextField("Server", text: $store.configuration.profile.server)
                TextField("Port", value: $store.configuration.profile.port, format: .number)
                SecureField("UUID", text: $store.configuration.profile.uuid)
                Picker("Security", selection: $store.configuration.profile.security) {
                    ForEach(VLESSProfile.Security.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
                }
                Picker("Transport", selection: $store.configuration.profile.transport) {
                    ForEach(VLESSProfile.Transport.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
                }
                TextField("Server name / SNI", text: $store.configuration.profile.serverName)
                TextField("Public key", text: $store.configuration.profile.publicKey)
                TextField("Short ID", text: $store.configuration.profile.shortID)
                TextField("Flow", text: $store.configuration.profile.flow)
            }
            .formStyle(.grouped)
        }
    }
}

