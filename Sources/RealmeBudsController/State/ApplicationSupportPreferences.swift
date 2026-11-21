import Foundation

@MainActor
enum ApplicationSupportPreferences {
    private static let directoryName = "Realme Buds Controller"
    private static let fileName = "preferences.json"

    private static var fileURL: URL? {
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        let directory = support.appendingPathComponent(directoryName, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appendingPathComponent(fileName)
    }

    static func load<T: Decodable>(key: String, default defaultValue: T) -> T {
        guard let data = try? Data(contentsOf: fileURLRequired),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = object[key] else {
            return defaultValue
        }

        if let typed = value as? T {
            return typed
        }
        if let data = try? JSONSerialization.data(withJSONObject: value),
           let decoded = try? JSONDecoder().decode(T.self, from: data) {
            return decoded
        }
        return defaultValue
    }

    static func save<T: Encodable>(key: String, value: T) {
        guard let url = fileURL else { return }
        var object: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            object = existing
        }
        if let encoded = try? JSONEncoder().encode(value),
           let jsonValue = try? JSONSerialization.jsonObject(with: encoded) {
            object[key] = jsonValue
        } else {
            object[key] = value
        }
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]) else {
            return
        }
        try? data.write(to: url, options: .atomic)
    }

    private static var fileURLRequired: URL {
        fileURL ?? URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("RealmeBudsController-preferences.json")
    }
}
