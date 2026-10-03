import Foundation

struct VaultPayload: Codable, Equatable, Sendable {
    var savedAt: Date
    var entries: [PasswordEntry]

    static let empty = VaultPayload(savedAt: .now, entries: [])

    var activeEntries: [PasswordEntry] { entries.filter { !$0.isDeleted } }
    var deletedEntries: [PasswordEntry] { entries.filter(\.isDeleted) }
}

struct KDFParameters: Codable, Equatable, Sendable {
    let algorithm: String
    let opsLimit: Int
    let memLimit: Int
    let salt: Data

    static func production(salt: Data) -> KDFParameters {
        KDFParameters(
            algorithm: "argon2id13",
            opsLimit: 3,
            memLimit: 32 * 1_024 * 1_024,
            salt: salt
        )
    }
}

struct VaultFileV1: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let kdf: KDFParameters
    let wrappedVaultKey: Data
    let encryptedPayload: Data
}

struct OpenedVault: Equatable, Sendable {
    var file: VaultFileV1
    var payload: VaultPayload
    var vaultKey: [UInt8]
}

struct BackupPreview: Equatable, Sendable {
    let savedAt: Date
    let activeCount: Int
    let deletedCount: Int
}

enum VaultError: LocalizedError, Equatable {
    case notConfigured
    case unsupportedVersion
    case invalidFormat
    case wrongPasswordOrCorrupted
    case keyDerivationFailed
    case encryptionFailed
    case storageFailure(String)
    case biometricUnavailable
    case biometricFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: "尚未创建密码库。"
        case .unsupportedVersion: "该密码库版本暂不受支持。"
        case .invalidFormat: "密码库文件格式无效。"
        case .wrongPasswordOrCorrupted: "主密码错误，或密码库文件已损坏。"
        case .keyDerivationFailed: "无法从主密码派生安全密钥。"
        case .encryptionFailed: "加密操作失败。"
        case let .storageFailure(message): "无法访问本地密码库：\(message)"
        case .biometricUnavailable: "Face ID 当前不可用。"
        case .biometricFailed: "Face ID 验证失败，请使用主密码。"
        }
    }
}
