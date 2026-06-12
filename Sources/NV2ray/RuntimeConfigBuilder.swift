import Foundation

enum RuntimeConfigBuilder {
    static func build(_ config: AppConfiguration) throws -> [String: Any] {
        let proxy = makeProxy(config.profile)
        let dns = makeDNS(config.dns)
        let route = makeRoute(config)

        return [
            "log": ["level": "info", "timestamp": true],
            "dns": dns,
            "inbounds": [[
                "type": "tun",
                "tag": "tun-in",
                "address": ["172.19.0.1/30", "fdfe:dcba:9876::1/126"],
                "auto_route": true,
                "strict_route": true,
                "stack": config.tunnel.killSwitch ? "gvisor" : "system"
            ]],
            "outbounds": [
                proxy,
                ["type": "direct", "tag": "direct"]
            ],
            "route": route
        ]
    }

    private static func makeProxy(_ profile: ProxyProfile) -> [String: Any] {
        switch profile.protocolType {
        case .vless:
            var outbound: [String: Any] = [
                "type": "vless",
                "tag": "proxy",
                "server": profile.server,
                "server_port": profile.port,
                "uuid": profile.uuid
            ]
            if !profile.flow.isEmpty { outbound["flow"] = profile.flow }
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

        case .hysteria2:
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
            let ports = profile.serverPorts.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
            if ports.isEmpty { outbound["server_port"] = profile.port }
            else { outbound["server_ports"] = ports }
            if profile.upMbps > 0 { outbound["up_mbps"] = profile.upMbps }
            if profile.downMbps > 0 { outbound["down_mbps"] = profile.downMbps }
            if profile.hysteriaNetwork != .both { outbound["network"] = profile.hysteriaNetwork.rawValue }
            if !profile.hopInterval.isEmpty { outbound["hop_interval"] = profile.hopInterval }
            if !profile.hopIntervalMax.isEmpty { outbound["hop_interval_max"] = profile.hopIntervalMax }
            if profile.obfsType != .none {
                outbound["obfs"] = ["type": profile.obfsType.rawValue, "password": profile.obfsPassword]
            }
            return outbound
        }
    }

    private static func makeDNS(_ settings: DNSSettings) -> [String: Any] {
        switch settings.mode {
        case .system:
            return ["servers": [["type": "local", "tag": "local"]], "final": "local"]
        case .dot:
            return [
                "servers": [[
                    "type": "tls",
                    "tag": "secure",
                    "server": settings.bootstrap,
                    "detour": settings.routeThroughProxy ? "proxy" : "direct"
                ]],
                "final": "secure"
            ]
        case .doh:
            let url = URL(string: settings.dohURL)
            let host = url?.host ?? settings.dohURL
            let path = url?.path.isEmpty == false ? url!.path : "/dns-query"
            return [
                "servers": [
                    [
                        "type": "https",
                        "tag": "secure",
                        "server": host,
                        "server_port": url?.port ?? 443,
                        "path": path,
                        "domain_resolver": "bootstrap",
                        "detour": settings.routeThroughProxy ? "proxy" : "direct"
                    ],
                    ["type": "udp", "tag": "bootstrap", "server": settings.bootstrap]
                ],
                "final": "secure"
            ]
        }
    }

    private static func makeRoute(_ config: AppConfiguration) -> [String: Any] {
        var rules: [[String: Any]] = []
        for rule in config.rules where rule.enabled {
            var item: [String: Any] = ["action": rule.action == .block ? "reject" : "route"]
            if rule.action != .block { item["outbound"] = rule.action.rawValue }
            switch rule.matcher {
            case .domain: item["domain"] = rule.values
            case .domainSuffix: item["domain_suffix"] = rule.values
            case .domainKeyword: item["domain_keyword"] = rule.values
            case .ipCIDR: item["ip_cidr"] = rule.values
            case .processName: item["process_name"] = rule.values
            case .processPath: item["process_path"] = rule.values
            case .port: item["port"] = rule.values.compactMap(Int.init)
            case .protocolType: item["network"] = rule.values
            case .ruleSet: item["rule_set"] = rule.values
            }
            rules.append(item)
        }

        return [
            "auto_detect_interface": true,
            "rules": rules,
            "final": config.routingMode == .direct ? "direct" : "proxy",
            "rule_set": [[
                "type": "remote",
                "tag": "category-ru",
                "format": "binary",
                "url": "https://raw.githubusercontent.com/SagerNet/sing-geosite/rule-set/geosite-category-ru.srs",
                "download_detour": "direct",
                "update_interval": "24h"
            ]]
        ]
    }
}
