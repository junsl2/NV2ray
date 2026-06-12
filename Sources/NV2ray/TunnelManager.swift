@preconcurrency import Foundation
@preconcurrency import NetworkExtension

private struct TunnelManagerList: @unchecked Sendable {
    let managers: [NETunnelProviderManager]
}

@MainActor
final class TunnelManager {
    static let providerBundleIdentifier = "io.github.junsl2.NV2ray.PacketTunnel"
    static let localizedDescription = "NV2ray"

    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    var onStatusChange: ((ConnectionState) -> Void)?

    func prepare() async throws {
        manager = try await loadOrCreateManager()
        observeStatus()
        publishStatus()
    }

    func connect(configContent: String, tunnelSettings: TunnelSettings) async throws {
        let manager = try await loadOrCreateManager()

        guard manager.connection.status == .disconnected || manager.connection.status == .invalid else {
            return
        }

        try await apply(tunnelSettings, to: manager)
        self.manager = manager
        observeStatus()

        let options: [String: NSObject] = [
            "configContent": configContent as NSString,
            "includeAllNetworks": NSNumber(value: tunnelSettings.killSwitch),
            "systemProxyEnabled": NSNumber(value: false),
            "excludeDefaultRoute": NSNumber(value: false),
            "autoRouteUseSubRangesByDefault": NSNumber(value: false)
        ]
        try manager.connection.startVPNTunnel(options: options)
        publishStatus()
    }

    func disconnect() async throws {
        guard let manager else { return }

        // Disable On Demand first so an intentional Stop action does not
        // immediately reconnect the VPN profile.
        if manager.isOnDemandEnabled {
            manager.isOnDemandEnabled = false
            manager.onDemandRules = []
            try await save(manager)
            try await load(manager)
        }

        manager.connection.stopVPNTunnel()
        publishStatus()
    }

    private func apply(_ settings: TunnelSettings, to manager: NETunnelProviderManager) async throws {
        let tunnelProtocol = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = Self.providerBundleIdentifier
        tunnelProtocol.serverAddress = Self.localizedDescription

        // includeAllNetworks is the system-level fail-closed path. It keeps
        // traffic scoped to the Packet Tunnel instead of allowing another
        // interface to become a bypass route while the VPN is active.
        tunnelProtocol.includeAllNetworks = settings.killSwitch
        tunnelProtocol.enforceRoutes = settings.killSwitch
        tunnelProtocol.excludeLocalNetworks = settings.killSwitch && settings.allowLocalNetwork

        manager.protocolConfiguration = tunnelProtocol
        manager.localizedDescription = Self.localizedDescription
        manager.isEnabled = true
        manager.onDemandRules = settings.killSwitch ? [NEOnDemandRuleConnect()] : []
        manager.isOnDemandEnabled = settings.killSwitch

        try await save(manager)
        try await load(manager)
    }

    private func loadOrCreateManager() async throws -> NETunnelProviderManager {
        let existing = try await loadManagers().first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == Self.providerBundleIdentifier
        }
        if let existing {
            return existing
        }

        let manager = NETunnelProviderManager()
        let tunnelProtocol = NETunnelProviderProtocol()
        tunnelProtocol.providerBundleIdentifier = Self.providerBundleIdentifier
        tunnelProtocol.serverAddress = Self.localizedDescription
        manager.protocolConfiguration = tunnelProtocol
        manager.localizedDescription = Self.localizedDescription
        manager.isEnabled = true
        try await save(manager)
        try await load(manager)
        return manager
    }

    private func observeStatus() {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager?.connection,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.publishStatus() }
        }
    }

    private func publishStatus() {
        guard let status = manager?.connection.status else {
            onStatusChange?(.disconnected)
            return
        }
        switch status {
        case .connecting, .reasserting:
            onStatusChange?(.connecting)
        case .connected:
            onStatusChange?(.connected)
        case .disconnecting, .disconnected, .invalid:
            onStatusChange?(.disconnected)
        @unknown default:
            onStatusChange?(.error)
        }
    }

    private func loadManagers() async throws -> [NETunnelProviderManager] {
        let list: TunnelManagerList = try await withCheckedThrowingContinuation { continuation in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: TunnelManagerList(managers: managers ?? [])) }
            }
        }
        return list.managers
    }

    private func save(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }

    private func load(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.loadFromPreferences { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: ()) }
            }
        }
    }
}
