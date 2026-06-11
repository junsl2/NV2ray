import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var configuration = AppConfiguration()
    @Published var connectionState: ConnectionState = .disconnected
    @Published var lastError: String?

    private let configURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NV2ray", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        configURL = base.appendingPathComponent("configuration.json")
        load()
    }

    func connect() async {
        guard !configuration.profile.server.isEmpty,
              !configuration.profile.uuid.isEmpty else {
            lastError = "Server and UUID are required."
            connectionState = .error
            return
        }

        connectionState = .connecting
        save()

        try? await Task.sleep(for: .milliseconds(450))
        connectionState = .connected
    }

    func disconnect() {
        connectionState = .disconnected
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
            let dictionary = try SingBoxConfigBuilder.build(configuration)
            let data = try JSONSerialization.data(withJSONObject: dictionary, options: [.prettyPrinted, .sortedKeys])
            return String(decoding: data, as: UTF8.self)
        } catch {
            return "{\"error\":\"\(error.localizedDescription)\"}"
        }
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
