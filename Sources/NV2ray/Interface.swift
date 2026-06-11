import SwiftUI

struct MenuPanel: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NV2ray").font(.headline.weight(.semibold))
                    Text(store.connectionState.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: store.connectionState.iconName)
                    .font(.title3)
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
            .buttonStyle(GlassPrimaryButtonStyle())

            Button("Settings") { openSettings() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
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
                .tabItem { Label("Connection", systemImage: "bolt.horizontal.circle") }
            DNSSettingsView()
                .tabItem { Label("DNS", systemImage: "network") }
            RoutingSettingsView()
                .tabItem { Label("Routing", systemImage: "arrow.triangle.branch") }
            AdvancedView(generatedConfig: $generatedConfig)
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .padding(18)
        .preferredColorScheme(.dark)
        .background(BlackGlassBackground())
    }
}

struct DNSSettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        SettingsCard(title: "Custom DNS", subtitle: "Resolver, bootstrap and fallback settings") {
            Form {
                Picker("Mode", selection: $store.configuration.dns.mode) {
                    ForEach(DNSSettings.Mode.allCases, id: \.self) {
                        Text($0.rawValue.uppercased()).tag($0)
                    }
                }
                TextField("DoH URL", text: $store.configuration.dns.dohURL)
                TextField("Bootstrap DNS", text: $store.configuration.dns.bootstrap)
                TextField("Fallback URL", text: $store.configuration.dns.fallbackURL)
                Toggle("Route DNS through active profile", isOn: $store.configuration.dns.routeThroughProxy)
                Toggle("Block IPv6 answers", isOn: $store.configuration.dns.blockIPv6)
            }
            .formStyle(.grouped)
        }
    }
}

struct RoutingSettingsView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        SettingsCard(title: "Routing rules", subtitle: "Rules are evaluated from top to bottom") {
            VStack(spacing: 12) {
                Picker("Mode", selection: $store.configuration.routingMode) {
                    ForEach(AppConfiguration.RoutingMode.allCases, id: \.self) {
                        Text($0.rawValue.capitalized).tag($0)
                    }
                }
                .pickerStyle(.segmented)

                ForEach($store.configuration.rules) { $rule in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Toggle("", isOn: $rule.enabled).labelsHidden()
                            TextField("Rule name", text: $rule.name)
                            Spacer()
                            Button(role: .destructive) {
                                store.configuration.rules.removeAll { $0.id == rule.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                        HStack {
                            Picker("Matcher", selection: $rule.matcher) {
                                ForEach(RouteRule.Matcher.allCases, id: \.self) {
                                    Text($0.rawValue).tag($0)
                                }
                            }
                            Picker("Action", selection: $rule.action) {
                                ForEach(RouteRule.Action.allCases, id: \.self) {
                                    Text($0.rawValue.capitalized).tag($0)
                                }
                            }
                        }
                        TextField("Values separated by commas", text: Binding(
                            get: { rule.values.joined(separator: ", ") },
                            set: { rule.values = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } }
                        ))
                    }
                    .padding(14)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }

                Button {
                    store.configuration.rules.append(RouteRule())
                } label: {
                    Label("Add rule", systemImage: "plus")
                }
            }
        }
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.8)
        }
    }
}

struct BlackGlassBackground: View {
    var body: some View {
        ZStack {
            Color.black
            RadialGradient(colors: [.white.opacity(0.07), .clear], center: .topLeading, startRadius: 10, endRadius: 620)
            LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}

struct GlassPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.semibold)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(configuration.isPressed ? 0.16 : 0.11), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.18)))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

enum SingBoxConfigBuilder {
    static func build(_ config: AppConfiguration) throws -> [String: Any] {
        let rules = config.rules.filter(\.enabled).map { rule in
            [
                "name": rule.name,
                "matcher": rule.matcher.rawValue,
                "values": rule.values,
                "action": rule.action.rawValue
            ] as [String: Any]
        }

        return [
            "profile": [
                "type": "vless",
                "server": config.profile.server,
                "port": config.profile.port,
                "uuid": config.profile.uuid,
                "security": config.profile.security.rawValue,
                "transport": config.profile.transport.rawValue,
                "server_name": config.profile.serverName,
                "public_key": config.profile.publicKey,
                "short_id": config.profile.shortID,
                "flow": config.profile.flow
            ],
            "dns": [
                "mode": config.dns.mode.rawValue,
                "url": config.dns.dohURL,
                "bootstrap": config.dns.bootstrap,
                "fallback": config.dns.fallbackURL,
                "through_profile": config.dns.routeThroughProxy,
                "block_ipv6": config.dns.blockIPv6
            ],
            "routing": [
                "mode": config.routingMode.rawValue,
                "rules": rules
            ]
        ]
    }
}
