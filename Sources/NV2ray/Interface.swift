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
            "outbounds": [makeOutbound(config.profile)],
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

    private static func makeOutbound(_ profile: ProxyProfile) -> [String: Any] {
        switch profile.protocolType {
        case .vless:
            return makeVLESSOutbound(profile)
        case .hysteria2:
            return makeHysteria2Outbound(profile)
        }
    }

    private static func makeVLESSOutbound(_ profile: ProxyProfile) -> [String: Any] {
        var outbound: [String: Any] = [
            "type": "vless",
            "tag": "proxy",
            "server": profile.server,
            "server_port": profile.port,
            "uuid": profile.uuid
        ]

        if !profile.flow.isEmpty {
            outbound["flow"] = profile.flow
        }

        if profile.transport != .tcp {
            outbound["transport"] = ["type": profile.transport.configValue]
        }

        if profile.security != .none {
            var tls: [String: Any] = [
                "enabled": true,
                "server_name": profile.serverName,
                "insecure": profile.allowInsecure,
                "utls": ["enabled": true, "fingerprint": profile.fingerprint]
            ]

            if profile.security == .reality {
                tls["reality"] = [
                    "enabled": true,
                    "public_key": profile.publicKey,
                    "short_id": profile.shortID
                ]
            }
            outbound["tls"] = tls
        }

        return outbound
    }

    private static func makeHysteria2Outbound(_ profile: ProxyProfile) -> [String: Any] {
        var outbound: [String: Any] = [
            "type": "hysteria2",
            "tag": "proxy",
            "server": profile.server,
            "password": profile.hysteriaPassword,
            "tls": [
                "enabled": true,
                "server_name": profile.serverName,
                "insecure": profile.allowInsecure
            ]
        ]

        let ports = profile.serverPorts
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if ports.isEmpty {
            outbound["server_port"] = profile.port
        } else {
            outbound["server_ports"] = ports
        }

        if profile.upMbps > 0 {
            outbound["up_mbps"] = profile.upMbps
        }
        if profile.downMbps > 0 {
            outbound["down_mbps"] = profile.downMbps
        }
        if profile.hysteriaNetwork != .both {
            outbound["network"] = profile.hysteriaNetwork.rawValue
        }
        if !profile.hopInterval.isEmpty {
            outbound["hop_interval"] = profile.hopInterval
        }
        if !profile.hopIntervalMax.isEmpty {
            outbound["hop_interval_max"] = profile.hopIntervalMax
        }
        if profile.obfsType != .none {
            outbound["obfs"] = [
                "type": profile.obfsType.rawValue,
                "password": profile.obfsPassword
            ]
        }

        return outbound
    }
}
