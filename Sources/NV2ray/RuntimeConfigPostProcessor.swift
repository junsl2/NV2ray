import Foundation

enum RuntimeConfigPostProcessor {
    static func apply(to runtime: [String: Any], using config: AppConfiguration) -> [String: Any] {
        var result = runtime
        result["dns"] = hardenDNS(runtime["dns"], settings: config.dns)
        return result
    }

    private static func hardenDNS(_ value: Any?, settings: DNSSettings) -> [String: Any] {
        var dns = (value as? [String: Any]) ?? [:]
        dns["strategy"] = settings.blockIPv6 ? "ipv4_only" : "prefer_ipv4"
        return dns
    }
}
