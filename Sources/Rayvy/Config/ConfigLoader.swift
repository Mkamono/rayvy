import Foundation
import TOMLKit

enum ConfigLoader {
    static var configDirectoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("rayvy", isDirectory: true)
    }

    static var configFileURL: URL {
        configDirectoryURL.appendingPathComponent("config.toml", isDirectory: false)
    }

    /// Loads the config file, creating a default one on first run.
    /// Never throws: on any failure the previous/default config is returned so the app keeps running.
    static func loadOrCreateDefault() -> Config {
        let fileURL = configFileURL

        if !FileManager.default.fileExists(atPath: fileURL.path) {
            createDefaultConfigFile(at: fileURL)
            return .default
        }

        return load(from: fileURL) ?? .default
    }

    /// Reloads the config file. Returns `nil` if the file is missing or fails to parse,
    /// so callers can decide to keep the previous configuration.
    static func reload() -> Config? {
        load(from: configFileURL)
    }

    private static func load(from fileURL: URL) -> Config? {
        guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
            FileHandle.standardError.write(Data("[Rayvy] config: failed to read \(fileURL.path)\n".utf8))
            return nil
        }

        do {
            return try TOMLDecoder().decode(Config.self, from: contents)
        } catch {
            FileHandle.standardError.write(Data("[Rayvy] config: failed to parse \(fileURL.path): \(error)\n".utf8))
            return nil
        }
    }

    private static func createDefaultConfigFile(at fileURL: URL) {
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try ConfigDefaults.template.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            FileHandle.standardError.write(Data("[Rayvy] config: failed to create default config: \(error)\n".utf8))
        }
    }
}
