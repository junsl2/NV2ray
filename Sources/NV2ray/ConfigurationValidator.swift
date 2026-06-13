import Foundation

enum ConfigurationValidationError: LocalizedError {
    case emptyServer
    case invalidPort
    case missingVLESSUUID
    case missingHysteriaPassword
    case systemDNSWithKillSwitch
    case directModeWithKillSwitch

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
        case .systemDNSWithKillSwitch:
            return "System DNS is not allowed while traffic protection is enabled. Choose DoH or DoT."
        case .directModeWithKillSwitch:
            return "Direct routing mode is not allowed while traffic protection is enabled. Choose Rule or Global."
        }
    }
}

enum ConfigurationValidator {
    static func validate(_ config: AppConfiguration) throws {
        let profile = config.profile
        guard !profile.server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
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
        case .hysteria2:
            guard !profile.hysteriaPassword.isEmpty else {
                throw ConfigurationValidationError.missingHysteriaPassword
            }
        }

        guard !(config.tunnel.killSwitch && config.dns.mode == .system) else {
            throw ConfigurationValidationError.systemDNSWithKillSwitch
        }
        guard !(config.tunnel.killSwitch && config.routingMode == .direct) else {
            throw ConfigurationValidationError.directModeWithKillSwitch
        }
    }
}
