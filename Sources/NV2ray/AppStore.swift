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
        try ConfigurationValidator.validate(configuration)
        let dictionary = try RuntimeConfigBuilder.build(configuration)
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
        return String(decoding: data, as: UTF8.self)
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
