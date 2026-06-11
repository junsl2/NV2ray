import SwiftUI

struct MenuPanel: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("NV2ray").font(.headline)
                Spacer()
                Image(systemName: store.connectionState.iconName)
            }

            Picker("Routing", selection: $store.configuration.routingMode) {
                ForEach(AppConfiguration.RoutingMode.allCases, id: \.self) {
                    Text($0.rawValue.capitalized).tag($0)
                }
            }
            .pickerStyle(.segmented)

            Button(store.connectionState == .connected ? "Stop" : "Start") {
                Task {
                    if store.connectionState == .connected {
                        store.disconnect()
                    } else {
                        await store.connect()
                    }
                }
            }

            Button("Settings") { openSettings() }
        }
        .padding(16)
        .preferredColorScheme(.dark)
        .background(BlackGlassBackground())
    }
}

struct SettingsRootView: View {
    @State private var generatedConfig = ""

    var body: some View {
        TabView {
            ConnectionSettingsView()
                .tabItem { Text("Connection") }
            AdvancedView(generatedConfig: $generatedConfig)
                .tabItem { Text("Advanced") }
        }
        .padding(18)
        .preferredColorScheme(.dark)
        .background(BlackGlassBackground())
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
            content
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
    }
}

struct BlackGlassBackground: View {
    var body: some View {
        ZStack {
            Color.black
            LinearGradient(colors: [.white.opacity(0.06), .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .ignoresSafeArea()
    }
}

enum SingBoxConfigBuilder {
    static func build(_ config: AppConfiguration) throws -> [String: Any] {
        [
            "profile": config.profile.name,
            "server": config.profile.server,
            "dns": config.dns.dohURL,
            "routing": config.routingMode.rawValue
        ]
    }
}
