import SwiftUI

struct ConnectionSettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        SettingsCard(
            title: "Proxy connection",
            subtitle: "VLESS and Hysteria2 profile options"
        ) {
            Form {
                Picker("Protocol", selection: $store.configuration.profile.protocolType) {
                    ForEach(ProxyProfile.ProtocolType.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }

                TextField("Profile name", text: $store.configuration.profile.name)
                TextField("Server", text: $store.configuration.profile.server)
                TextField("Port", value: $store.configuration.profile.port, format: .number)

                if store.configuration.profile.protocolType == .vless {
                    SecureField("UUID", text: $store.configuration.profile.uuid)

                    Picker("Security", selection: $store.configuration.profile.security) {
                        ForEach(ProxyProfile.VLESSSecurity.allCases, id: \.self) {
                            Text($0.rawValue.uppercased()).tag($0)
                        }
                    }

                    Picker("Transport", selection: $store.configuration.profile.transport) {
                        ForEach(ProxyProfile.VLESSTransport.allCases, id: \.self) {
                            Text($0.rawValue.uppercased()).tag($0)
                        }
                    }

                    TextField("Server name / SNI", text: $store.configuration.profile.serverName)

                    if store.configuration.profile.security == .reality {
                        TextField("Reality public key", text: $store.configuration.profile.publicKey)
                        TextField("Reality short ID", text: $store.configuration.profile.shortID)
                        TextField("uTLS fingerprint", text: $store.configuration.profile.fingerprint)
                    }

                    TextField("Flow", text: $store.configuration.profile.flow)
                    Toggle("Allow insecure TLS", isOn: $store.configuration.profile.allowInsecure)
                } else {
                    SecureField("Authentication password", text: $store.configuration.profile.hysteriaPassword)
                    TextField("Server name / SNI", text: $store.configuration.profile.serverName)
                    Toggle("Allow insecure TLS", isOn: $store.configuration.profile.allowInsecure)

                    Picker("Enabled network", selection: $store.configuration.profile.hysteriaNetwork) {
                        ForEach(ProxyProfile.HysteriaNetwork.allCases, id: \.self) {
                            Text($0.rawValue.uppercased()).tag($0)
                        }
                    }

                    TextField("Upload limit (Mbps, 0 = BBR)", value: $store.configuration.profile.upMbps, format: .number)
                    TextField("Download limit (Mbps, 0 = BBR)", value: $store.configuration.profile.downMbps, format: .number)
                    TextField("Server ports / ranges", text: $store.configuration.profile.serverPorts)
                    TextField("Port hop interval", text: $store.configuration.profile.hopInterval)
                    TextField("Maximum hop interval", text: $store.configuration.profile.hopIntervalMax)

                    Picker("QUIC obfuscation", selection: $store.configuration.profile.obfsType) {
                        ForEach(ProxyProfile.HysteriaObfs.allCases, id: \.self) {
                            Text($0.rawValue.capitalized).tag($0)
                        }
                    }

                    if store.configuration.profile.obfsType != .none {
                        SecureField("Obfuscation password", text: $store.configuration.profile.obfsPassword)
                    }
                }
            }
            .formStyle(.grouped)
        }
    }
}
