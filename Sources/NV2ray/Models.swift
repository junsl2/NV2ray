import Foundation

struct VLESSProfile: Codable, Identifiable, Hashable {
    var id = UUID()
    var name = "Primary"
    var server = ""
    var port = 443
    var uuid = ""
    var security: Security = .reality
    var transport: Transport = .tcp
    var flow = "xtls-rprx-vision"
    var serverName = "www.bing.com"
    var publicKey = ""
    var shortID = ""
    var fingerprint = "chrome"

    enum Security: String, Codable, CaseIterable { case none, tls, reality }
    enum Transport: String, Codable, CaseIterable { case tcp, websocket, http, xhttp }
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
    var profile = VLESSProfile()
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
