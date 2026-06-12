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

    func connect(configContent: String) async throws {
        let manager = try await loadOrCreateManager()
        self.manager = manager
        observeStatus()

        guard manager.connection.status == .disconnected || manager.connection.status == .invalid else {
            return
        }

        let options: [String: NSObject] = [
            "configContent": configContent as NSString,
            "includeAllNetworks": NSNumber(value: false),
            "systemProxyEnabled": NSNumber(value: false),
            "excludeDefaultRoute": NSNumber(value: false)
        ]
        try manager.connection.startVPNTunnel(options: options)
        publishStatus()
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
        publishStatus()
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
