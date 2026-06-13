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
        do {
            try ConfigurationValidator.validate(configuration)
        } catch {
            lastError = error.localizedDescription
            connectionState = .error
            return
        }

        connectionState = .connecting
        save()

        do {
            let config = try generatedConfigString()
            try await tunnelManager.connect(
                configContent: config,
                tunnelSettings: configuration.tunnel
            )
        } catch {
            lastError = error.localizedDescription
            connectionState = .error
        }
    }

    func disconnect() {
        Task {
            do {
                try await tunnelManager.disconnect()
            } catch {
                lastError = error.localizedDescription
                connectionState = .error
            }
        }
    }

    func save() {
        do {
            try saveSecretsToKeychain()
            let data = try JSONEncoder.pretty.encode(redactedConfigurationForDisk())
            try data.write(to: configURL, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configURL.path)
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
        try ConfigurationValidator.validate(configuration)
        let dictionary = try RuntimeConfigBuilder.build(configuration)
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func load() {
        guard let data = try? Data(contentsOf: configURL),
              var value = try? JSONDecoder().decode(AppConfiguration.self, from: data) else { return }
        do {
            try loadSecretsFromKeychain(into: &value)
        } catch {
            lastError = error.localizedDescription
        }
        configuration = value
    }

    private func redactedConfigurationForDisk() -> AppConfiguration {
        var redacted = configuration
        redacted.profile.uuid = ""
        redacted.profile.hysteriaPassword = ""
        redacted.profile.obfsPassword = ""
        return redacted
    }

    private func saveSecretsToKeychain() throws {
        try KeychainStore.set(configuration.profile.uuid, for: "profile.uuid")
        try KeychainStore.set(configuration.profile.hysteriaPassword, for: "profile.hysteriaPassword")
        try KeychainStore.set(configuration.profile.obfsPassword, for: "profile.obfsPassword")
    }

    private func loadSecretsFromKeychain(into config: inout AppConfiguration) throws {
        config.profile.uuid = try KeychainStore.get("profile.uuid")
        config.profile.hysteriaPassword = try KeychainStore.get("profile.hysteriaPassword")
        config.profile.obfsPassword = try KeychainStore.get("profile.obfsPassword")
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
