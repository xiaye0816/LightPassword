import Foundation
import Sodium

protocol VaultCrypto {
    func createVault(password: String, payload: VaultPayload) throws -> OpenedVault
    func openVault(data: Data, password: String) throws -> OpenedVault
    func openVault(data: Data, vaultKey: [UInt8]) throws -> OpenedVault
    func seal(_ openedVault: OpenedVault) throws -> (data: Data, vault: OpenedVault)
    func changePassword(data: Data, currentPassword: String, newPassword: String) throws -> (data: Data, vault: OpenedVault)
    func encode(_ file: VaultFileV1) throws -> Data
    func zero(_ bytes: inout [UInt8])
}

final class SodiumVaultCrypto: VaultCrypto {
    private let sodium = Sodium()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private let keyAAD = Array("LightPassword-VaultKey-v1".utf8)
    private let payloadAAD = Array("LightPassword-Payload-v1".utf8)

    init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        self.decoder = decoder
    }

    func createVault(password: String, payload: VaultPayload = .empty) throws -> OpenedVault {
        guard let salt = sodium.randomBytes.buf(length: sodium.pwHash.SaltBytes) else {
            throw VaultError.encryptionFailed
        }
        let vaultKey = sodium.aead.xchacha20poly1305ietf.key()
        let parameters = KDFParameters.production(salt: Data(salt))
        var passwordBytes = Array(password.utf8)
        defer { sodium.utils.zero(&passwordBytes) }
        var wrappingKey = try deriveKey(passwordBytes: passwordBytes, parameters: parameters)
        defer { sodium.utils.zero(&wrappingKey) }

        guard let wrappedKey: [UInt8] = sodium.aead.xchacha20poly1305ietf.encrypt(
            message: vaultKey,
            secretKey: wrappingKey,
            additionalData: keyAAD
        ) else {
            throw VaultError.encryptionFailed
        }

        let payloadData = try encoder.encode(payload)
        var payloadBytes = Array(payloadData)
        defer { sodium.utils.zero(&payloadBytes) }
        guard let encryptedPayload: [UInt8] = sodium.aead.xchacha20poly1305ietf.encrypt(
            message: payloadBytes,
            secretKey: vaultKey,
            additionalData: payloadAAD
        ) else {
            throw VaultError.encryptionFailed
        }

        let file = VaultFileV1(
            version: VaultFileV1.currentVersion,
            kdf: parameters,
            wrappedVaultKey: Data(wrappedKey),
            encryptedPayload: Data(encryptedPayload)
        )
        return OpenedVault(file: file, payload: payload, vaultKey: vaultKey)
    }

    func openVault(data: Data, password: String) throws -> OpenedVault {
        let file = try decodeFile(data)
        var passwordBytes = Array(password.utf8)
        defer { sodium.utils.zero(&passwordBytes) }
        var wrappingKey = try deriveKey(passwordBytes: passwordBytes, parameters: file.kdf)
        defer { sodium.utils.zero(&wrappingKey) }

        guard let vaultKey = sodium.aead.xchacha20poly1305ietf.decrypt(
            nonceAndAuthenticatedCipherText: Array(file.wrappedVaultKey),
            secretKey: wrappingKey,
            additionalData: keyAAD
        ) else {
            throw VaultError.wrongPasswordOrCorrupted
        }
        return try open(file: file, vaultKey: vaultKey)
    }

    func openVault(data: Data, vaultKey: [UInt8]) throws -> OpenedVault {
        try open(file: decodeFile(data), vaultKey: vaultKey)
    }

    func seal(_ openedVault: OpenedVault) throws -> (data: Data, vault: OpenedVault) {
        var payload = openedVault.payload
        payload.savedAt = .now
        let plaintext = try encoder.encode(payload)
        var plaintextBytes = Array(plaintext)
        defer { sodium.utils.zero(&plaintextBytes) }
        guard let encryptedPayload: [UInt8] = sodium.aead.xchacha20poly1305ietf.encrypt(
            message: plaintextBytes,
            secretKey: openedVault.vaultKey,
            additionalData: payloadAAD
        ) else {
            throw VaultError.encryptionFailed
        }
        let file = VaultFileV1(
            version: openedVault.file.version,
            kdf: openedVault.file.kdf,
            wrappedVaultKey: openedVault.file.wrappedVaultKey,
            encryptedPayload: Data(encryptedPayload)
        )
        return (try encode(file), OpenedVault(file: file, payload: payload, vaultKey: openedVault.vaultKey))
    }

    func changePassword(
        data: Data,
        currentPassword: String,
        newPassword: String
    ) throws -> (data: Data, vault: OpenedVault) {
        var opened = try openVault(data: data, password: currentPassword)
        guard let salt = sodium.randomBytes.buf(length: sodium.pwHash.SaltBytes) else {
            throw VaultError.encryptionFailed
        }
        let parameters = KDFParameters.production(salt: Data(salt))
        var newPasswordBytes = Array(newPassword.utf8)
        defer { sodium.utils.zero(&newPasswordBytes) }
        var wrappingKey = try deriveKey(passwordBytes: newPasswordBytes, parameters: parameters)
        defer { sodium.utils.zero(&wrappingKey) }

        guard let wrappedKey: [UInt8] = sodium.aead.xchacha20poly1305ietf.encrypt(
            message: opened.vaultKey,
            secretKey: wrappingKey,
            additionalData: keyAAD
        ) else {
            throw VaultError.encryptionFailed
        }
        opened.file = VaultFileV1(
            version: opened.file.version,
            kdf: parameters,
            wrappedVaultKey: Data(wrappedKey),
            encryptedPayload: opened.file.encryptedPayload
        )
        return try seal(opened)
    }

    func encode(_ file: VaultFileV1) throws -> Data {
        do {
            return try encoder.encode(file)
        } catch {
            throw VaultError.invalidFormat
        }
    }

    func zero(_ bytes: inout [UInt8]) {
        sodium.utils.zero(&bytes)
    }

    private func decodeFile(_ data: Data) throws -> VaultFileV1 {
        let file: VaultFileV1
        do {
            file = try decoder.decode(VaultFileV1.self, from: data)
        } catch {
            throw VaultError.invalidFormat
        }
        guard file.version == VaultFileV1.currentVersion else {
            throw VaultError.unsupportedVersion
        }
        guard file.kdf.algorithm == "argon2id13",
              file.kdf.salt.count == sodium.pwHash.SaltBytes,
              file.kdf.opsLimit >= 2,
              file.kdf.memLimit >= 8 * 1_024 * 1_024,
              !file.wrappedVaultKey.isEmpty,
              !file.encryptedPayload.isEmpty else {
            throw VaultError.invalidFormat
        }
        return file
    }

    private func deriveKey(passwordBytes: [UInt8], parameters: KDFParameters) throws -> [UInt8] {
        guard let key = sodium.pwHash.hash(
            outputLength: sodium.aead.xchacha20poly1305ietf.KeyBytes,
            passwd: passwordBytes,
            salt: Array(parameters.salt),
            opsLimit: parameters.opsLimit,
            memLimit: parameters.memLimit,
            alg: .Argon2ID13
        ) else {
            throw VaultError.keyDerivationFailed
        }
        return key
    }

    private func open(file: VaultFileV1, vaultKey: [UInt8]) throws -> OpenedVault {
        guard vaultKey.count == sodium.aead.xchacha20poly1305ietf.KeyBytes,
              var plaintext = sodium.aead.xchacha20poly1305ietf.decrypt(
                nonceAndAuthenticatedCipherText: Array(file.encryptedPayload),
                secretKey: vaultKey,
                additionalData: payloadAAD
              ) else {
            throw VaultError.wrongPasswordOrCorrupted
        }
        defer { sodium.utils.zero(&plaintext) }
        do {
            let payload = try decoder.decode(VaultPayload.self, from: Data(plaintext))
            return OpenedVault(file: file, payload: payload, vaultKey: vaultKey)
        } catch {
            throw VaultError.wrongPasswordOrCorrupted
        }
    }
}
