import Foundation
import Combine

@MainActor
final class AppStore: ObservableObject {
    @Published var configuration = AppConfiguration()
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastError: String?

    private let configURL: URL
    private let tunnelManager = TunnelManager()

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NV2ray", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        configURL = base.appendingPathComponent("configuration.json")
        load()

        tunnelManager.onStatusChange = { [weak self] state in
            self?.connectionState = state
        }

        Task {
            do {
                try await tunnelManager.prepare()
            } catch {
                lastError = error.localizedDescription
                connectionState = .error
            }
        }
    }

    func connect() async {
        guard validateProfile() else {
            connectionState = .error
            return
        }

        connectionState = .connecting
        save()

        do {
            let config = try generatedConfigString()
            try await tunnelManager.connect(configContent: config)
        } catch {
            lastError = error.localizedDescription
            connectionState = .error
        }
    }

    func disconnect() {
        tunnelManager.disconnect()
    }

    func save() {
        do {
            let data = try JSONEncoder.pretty.encode(configuration)
            try data.write(to: configURL, options: .atomic)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func exportGeneratedConfig() -> String {
        do {
            return try generatedConfigString()
        } catch {
            return "{\"error\":\"\(error.localizedDescription)\"}"
        }
    }

    private func generatedConfigString() throws -> String {
        let dictionary = try SingBoxConfigBuilder.build(configuration)
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func validateProfile() -> Bool {
        let profile = configuration.profile
        guard !profile.server.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            lastError = "Server is required."
            return false
        }
        guard (1...65535).contains(profile.port) else {
            lastError = "Port must be between 1 and 65535."
            return false
        }

        switch profile.protocolType {
        case .vless:
            guard !profile.uuid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                lastError = "VLESS UUID is required."
                return false
            }
        case .hysteria2:
            guard !profile.hysteriaPassword.isEmpty else {
                lastError = "Hysteria2 password is required."
                return false
            }
        }

        lastError = nil
        return true
    }

    private func load() {
        guard let data = try? Data(contentsOf: configURL),
              let value = try? JSONDecoder().decode(AppConfiguration.self, from: data) else { return }
        configuration = value
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
