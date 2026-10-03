import Foundation
import SwiftUI
import UniformTypeIdentifiers

protocol BackupService {
    func exportData(from store: VaultStore) throws -> Data
    func preview(data: Data, password: String, crypto: VaultCrypto) throws -> BackupPreview
}

struct EncryptedBackupService: BackupService {
    func exportData(from store: VaultStore) throws -> Data {
        try store.read()
    }

    func preview(data: Data, password: String, crypto: VaultCrypto) throws -> BackupPreview {
        var opened = try crypto.openVault(data: data, password: password)
        defer { crypto.zero(&opened.vaultKey) }
        return BackupPreview(
            savedAt: opened.payload.savedAt,
            activeCount: opened.payload.activeEntries.count,
            deletedCount: opened.payload.deletedEntries.count
        )
    }
}

extension UTType {
    static let vaultBackup = UTType(filenameExtension: "vaultbackup") ?? .data
}

struct VaultBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.vaultBackup, .data] }
    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw VaultError.invalidFormat
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
