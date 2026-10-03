import Foundation

protocol VaultStore {
    var exists: Bool { get }
    var fileURL: URL { get }
    func read() throws -> Data
    func write(_ data: Data) throws
    func delete() throws
}

final class FileVaultStore: VaultStore {
    let fileURL: URL

    init(baseDirectory: URL? = nil) {
        let root = baseDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.fileURL = root
            .appendingPathComponent("LightPassword", isDirectory: true)
            .appendingPathComponent("vault.lp", isDirectory: false)
    }

    var exists: Bool { FileManager.default.fileExists(atPath: fileURL.path) }

    func read() throws -> Data {
        guard exists else { throw VaultError.notConfigured }
        do {
            return try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        } catch {
            throw VaultError.storageFailure(error.localizedDescription)
        }
    }

    func write(_ data: Data) throws {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: fileURL.path
            )
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableURL = fileURL
            try mutableURL.setResourceValues(values)
        } catch {
            throw VaultError.storageFailure(error.localizedDescription)
        }
    }

    func delete() throws {
        guard exists else { return }
        do {
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            throw VaultError.storageFailure(error.localizedDescription)
        }
    }
}
