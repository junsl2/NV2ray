import Foundation

struct ProxyProfile: Codable, Identifiable, Hashable {
    var id = UUID()
    var protocolType: ProtocolType = .vless
    var name = "Primary"
    var server = ""
    var port = 443
    var serverName = ""
    var allowInsecure = false

    // VLESS
    var uuid = ""
    var security: VLESSSecurity = .reality
    var transport: VLESSTransport = .tcp
    var flow = "xtls-rprx-vision"
    var publicKey = ""
    var shortID = ""
    var fingerprint = "chrome"

    // Hysteria2
    var hysteriaPassword = ""
    var hysteriaNetwork: HysteriaNetwork = .both
    var upMbps = 0
    var downMbps = 0
    var serverPorts = ""
    var hopInterval = ""
    var hopIntervalMax = ""
    var obfsType: HysteriaObfs = .none
    var obfsPassword = ""

    enum ProtocolType: String, Codable, CaseIterable {
        case vless
        case hysteria2

        var displayName: String {
            switch self {
            case .vless: return "VLESS"
            case .hysteria2: return "Hysteria2"
            }
        }
    }

    enum VLESSSecurity: String, Codable, CaseIterable {
        case none, tls, reality
    }

    enum VLESSTransport: String, Codable, CaseIterable {
        case tcp, websocket, http, xhttp

        var configValue: String {
            self == .websocket ? "ws" : rawValue
        }
    }

    enum HysteriaNetwork: String, Codable, CaseIterable {
        case both, tcp, udp
    }

    enum HysteriaObfs: String, Codable, CaseIterable {
        case none, salamander, gecko
    }

    private enum CodingKeys: String, CodingKey {
        case id, protocolType, name, server, port, serverName, allowInsecure
        case uuid, security, transport, flow, publicKey, shortID, fingerprint
        case hysteriaPassword, hysteriaNetwork, upMbps, downMbps, serverPorts
        case hopInterval, hopIntervalMax, obfsType, obfsPassword
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        protocolType = try container.decodeIfPresent(ProtocolType.self, forKey: .protocolType) ?? .vless
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Primary"
        server = try container.decodeIfPresent(String.self, forKey: .server) ?? ""
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 443
        serverName = try container.decodeIfPresent(String.self, forKey: .serverName) ?? ""
        allowInsecure = try container.decodeIfPresent(Bool.self, forKey: .allowInsecure) ?? false

        uuid = try container.decodeIfPresent(String.self, forKey: .uuid) ?? ""
        security = try container.decodeIfPresent(VLESSSecurity.self, forKey: .security) ?? .reality
        transport = try container.decodeIfPresent(VLESSTransport.self, forKey: .transport) ?? .tcp
        flow = try container.decodeIfPresent(String.self, forKey: .flow) ?? "xtls-rprx-vision"
        publicKey = try container.decodeIfPresent(String.self, forKey: .publicKey) ?? ""
        shortID = try container.decodeIfPresent(String.self, forKey: .shortID) ?? ""
        fingerprint = try container.decodeIfPresent(String.self, forKey: .fingerprint) ?? "chrome"

        hysteriaPassword = try container.decodeIfPresent(String.self, forKey: .hysteriaPassword) ?? ""
        hysteriaNetwork = try container.decodeIfPresent(HysteriaNetwork.self, forKey: .hysteriaNetwork) ?? .both
        upMbps = try container.decodeIfPresent(Int.self, forKey: .upMbps) ?? 0
        downMbps = try container.decodeIfPresent(Int.self, forKey: .downMbps) ?? 0
        serverPorts = try container.decodeIfPresent(String.self, forKey: .serverPorts) ?? ""
        hopInterval = try container.decodeIfPresent(String.self, forKey: .hopInterval) ?? ""
        hopIntervalMax = try container.decodeIfPresent(String.self, forKey: .hopIntervalMax) ?? ""
        obfsType = try container.decodeIfPresent(HysteriaObfs.self, forKey: .obfsType) ?? .none
        obfsPassword = try container.decodeIfPresent(String.self, forKey: .obfsPassword) ?? ""
    }
}

struct DNSSettings: Codable, Hashable {
    var mode: Mode = .doh
    var dohURL = "https://1.1.1.1/dns-query"
    var bootstrap = "1.1.1.1"
    var fallbackURL = "https://dns.google/dns-query"
    var routeThroughProxy = true
    var blockIPv6 = false

    enum Mode: String, Codable, CaseIterable { case system, doh, dot }
}

struct RouteRule: Codable, Identifiable, Hashable {
    var id = UUID()
    var enabled = true
    var name = "New rule"
    var matcher: Matcher = .domainSuffix
    var values: [String] = []
    var action: Action = .proxy

    enum Matcher: String, Codable, CaseIterable {
        case domain, domainSuffix, domainKeyword, ipCIDR, processName, processPath, port, protocolType, ruleSet
    }

    enum Action: String, Codable, CaseIterable { case proxy, direct, block }
}

struct AppConfiguration: Codable {
    var profile = ProxyProfile()
    var dns = DNSSettings()
    var routingMode: RoutingMode = .rule
    var rules: [RouteRule] = [
        RouteRule(name: "Private networks", matcher: .ipCIDR, values: ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"], action: .direct),
        RouteRule(name: "Russian domains", matcher: .ruleSet, values: ["category-ru"], action: .direct)
    ]
    var launchAtLogin = false

    enum RoutingMode: String, Codable, CaseIterable { case global, rule, direct }
}

enum ConnectionState: String {
    case disconnected, connecting, connected, error

    var iconName: String {
        switch self {
        case .disconnected: return "circle.dotted"
        case .connecting: return "arrow.triangle.2.circlepath.circle.fill"
        case .connected: return "bolt.horizontal.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}
