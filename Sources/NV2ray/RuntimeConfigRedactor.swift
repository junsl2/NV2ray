import Foundation

enum RuntimeConfigRedactor {
    static func redact(_ runtime: [String: Any]) -> [String: Any] {
        redactValue(runtime) as? [String: Any] ?? runtime
    }

    private static func redactValue(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            var redacted: [String: Any] = [:]
            for (key, nestedValue) in dictionary {
                if isSensitiveKey(key) {
                    redacted[key] = "<redacted>"
                } else {
                    redacted[key] = redactValue(nestedValue)
                }
            }
            return redacted
        }

        if let array = value as? [Any] {
            return array.map { redactValue($0) }
        }

        return value
    }

    private static func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key.lowercased()
        return normalized == "uuid"
            || normalized == "password"
            || normalized == "public_key"
            || normalized == "short_id"
            || normalized.contains("secret")
            || normalized.contains("token")
            || normalized.contains("credential")
    }
}
