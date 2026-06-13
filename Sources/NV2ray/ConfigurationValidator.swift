import Foundation

enum ConfigurationValidationError: LocalizedError {
    case emptyServer
    case invalidPort
    case missingVLESSUUID
    case missingHysteriaPassword
    case missingServerNameForTLS
    case insecureTLSWithKillSwitch
    case systemDNSWithKillSwitch
    case directModeWithKillSwitch
    case proxyDomainWithKillSwitch
    case resolverDomainWithKillSwitch
    case invalidDoHURL

    var errorDescription: String? {
        switch self {
        case .emptyServer:
            return "Server is required."
        case .invalidPort:
            return "Port must be between 1 and 65535."
        case .missingVLESSUUID:
            return "VLESS UUID is required."
        case .missingHysteriaPassword:
            return "Hysteria2 password is required."
        case .missingServerNameForTLS:
            return "TLS server name / SNI is required."
        case .insecureTLSWithKillSwitch:
            return "Insecure TLS is not allowed while traffic protection is enabled."
        case .systemDNSWithKillSwitch:
            return "System DNS is not allowed while traffic protection is enabled. Choose DoH or DoT."
        case .directModeWithKillSwitch:
            return "Direct routing mode is not allowed while traffic protection is enabled. Choose Rule or Global."
        case .proxyDomainWithKillSwitch:
            return "Traffic protection requires the proxy server field to be an IP address to avoid DNS bootstrap loops."
        case .resolverDomainWithKillSwitch:
            return "Traffic protection requires the encrypted DNS server host to be an IP address to avoid DNS bootstrap loops."
        case .invalidDoHURL:
            return "DoH URL is invalid."
        }
    }
}

enum ConfigurationValidator {
    static func validate(_ config: AppConfiguration) throws {
        let profile = config.profile
        let server = profile.server.trimmingCharacters(in: .whitespacesAndNewlines)
        let serverName = profile.serverName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !server.isEmpty else {
            throw ConfigurationValidationError.emptyServer
        }
        guard (1...65535).contains(profile.port) else {
            throw ConfigurationValidationError.invalidPort
        }

        switch profile.protocolType {
        case .vless:
            guard !profile.uuid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ConfigurationValidationError.missingVLESSUUID
            }
            if profile.security != .none && serverName.isEmpty {
                throw ConfigurationValidationError.missingServerNameForTLS
            }
        case .hysteria2:
            guard !profile.hysteriaPassword.isEmpty else {
                throw ConfigurationValidationError.missingHysteriaPassword
            }
            guard !serverName.isEmpty else {
                throw ConfigurationValidationError.missingServerNameForTLS
            }
        }

        guard !(config.tunnel.killSwitch && profile.allowInsecure) else {
            throw ConfigurationValidationError.insecureTLSWithKillSwitch
        }
        guard !(config.tunnel.killSwitch && config.dns.mode == .system) else {
            throw ConfigurationValidationError.systemDNSWithKillSwitch
        }
        guard !(config.tunnel.killSwitch && config.routingMode == .direct) else {
            throw ConfigurationValidationError.directModeWithKillSwitch
        }

        if config.tunnel.killSwitch {
            guard isIPAddress(server) else {
                throw ConfigurationValidationError.proxyDomainWithKillSwitch
            }
            try validateProtectedDNS(config.dns)
        }
    }

    private static func validateProtectedDNS(_ settings: DNSSettings) throws {
        switch settings.mode {
        case .system:
            throw ConfigurationValidationError.systemDNSWithKillSwitch
        case .dot:
            guard isIPAddress(settings.bootstrap.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw ConfigurationValidationError.resolverDomainWithKillSwitch
            }
        case .doh:
            guard let url = URL(string: settings.dohURL), let host = url.host, !host.isEmpty else {
                throw ConfigurationValidationError.invalidDoHURL
            }
            guard isIPAddress(host) else {
                throw ConfigurationValidationError.resolverDomainWithKillSwitch
            }
            guard isIPAddress(settings.bootstrap.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw ConfigurationValidationError.resolverDomainWithKillSwitch
            }
        }
    }

    private static func isIPAddress(_ value: String) -> Bool {
        isIPv4Address(value) || isLikelyIPv6Address(value)
    }

    private static func isIPv4Address(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard let number = Int(part), (0...255).contains(number) else { return false }
            return String(number) == part || part == "0"
        }
    }

    private static func isLikelyIPv6Address(_ value: String) -> Bool {
        guard value.contains(":") else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF:")
        return value.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
