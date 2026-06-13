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
            let config = try generatedConfigString(redacted: false)
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

    func exportGeneratedConfig(redacted: Bool = true) -> String {
        do {
            return try generatedConfigString(redacted: redacted)
        } catch {
            return "{\"error\":\"\(error.localizedDescription)\"}"
        }
    }

    private func generatedConfigString(redacted: Bool) throws -> String {
        try ConfigurationValidator.validate(configuration)
        var dictionary = try RuntimeConfigBuilder.build(configuration)
        dictionary = RuntimeConfigPostProcessor.apply(to: dictionary, using: configuration)
        if redacted {
            dictionary = RuntimeConfigRedactor.redact(dictionary)
        }
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
    }

    private func load() {
        guard let data = try? Data(contentsOf: configURL),
              var value = try? JSONDecoder().decode(AppConfiguration.self, from: data) else { return }
        do {
            try loadOrMigrateSecrets(into: &value)
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

    private func loadOrMigrateSecrets(into config: inout AppConfiguration) throws {
        let diskUUID = config.profile.uuid
        let diskHysteriaPassword = config.profile.hysteriaPassword
        let diskObfsPassword = config.profile.obfsPassword

        let keychainUUID = try KeychainStore.get("profile.uuid")
        let keychainHysteriaPassword = try KeychainStore.get("profile.hysteriaPassword")
        let keychainObfsPassword = try KeychainStore.get("profile.obfsPassword")

        config.profile.uuid = keychainUUID.isEmpty ? diskUUID : keychainUUID
        config.profile.hysteriaPassword = keychainHysteriaPassword.isEmpty ? diskHysteriaPassword : keychainHysteriaPassword
        config.profile.obfsPassword = keychainObfsPassword.isEmpty ? diskObfsPassword : keychainObfsPassword

        if !diskUUID.isEmpty || !diskHysteriaPassword.isEmpty || !diskObfsPassword.isEmpty {
            try KeychainStore.set(config.profile.uuid, for: "profile.uuid")
            try KeychainStore.set(config.profile.hysteriaPassword, for: "profile.hysteriaPassword")
            try KeychainStore.set(config.profile.obfsPassword, for: "profile.obfsPassword")
            self.configuration = config
            save()
        }
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
