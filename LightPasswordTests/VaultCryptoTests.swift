import Foundation
import Testing
@testable import LightPassword

struct VaultCryptoTests {
    private let password = "correct horse battery staple"

    @Test func roundTripDoesNotPersistPlaintext() throws {
        let crypto = SodiumVaultCrypto()
        let secret = "SENTINEL-password-never-plaintext"
        let entry = PasswordEntry(title: "测试账号", username: "alice@example.com", password: secret)
        let payload = VaultPayload(savedAt: .now, entries: [entry])

        let created = try crypto.createVault(password: password, payload: payload)
        let sealed = try crypto.seal(created)

        #expect(!sealed.data.contains(Data(secret.utf8)))
        #expect(!sealed.data.contains(Data("alice@example.com".utf8)))

        let reopened = try crypto.openVault(data: sealed.data, password: password)
        #expect(reopened.payload.entries.count == 1)
        #expect(reopened.payload.entries.first?.id == entry.id)
        #expect(reopened.payload.entries.first?.title == entry.title)
        #expect(reopened.payload.entries.first?.username == entry.username)
        #expect(reopened.payload.entries.first?.password == entry.password)
        let biometricOpen = try crypto.openVault(data: sealed.data, vaultKey: reopened.vaultKey)
        #expect(biometricOpen.payload.entries.first?.password == secret)
    }

    @Test func wrongPasswordAndTamperingAreRejected() throws {
        let crypto = SodiumVaultCrypto()
        let created = try crypto.createVault(
            password: password,
            payload: VaultPayload(savedAt: .now, entries: [PasswordEntry(title: "邮箱", password: "secret")])
        )
        let sealed = try crypto.seal(created)

        #expect(throws: VaultError.self) {
            _ = try crypto.openVault(data: sealed.data, password: "this password is incorrect")
        }

        var file = sealed.vault.file
        var ciphertext = Array(file.encryptedPayload)
        ciphertext[ciphertext.count - 1] ^= 0x01
        file = VaultFileV1(
            version: file.version,
            kdf: file.kdf,
            wrappedVaultKey: file.wrappedVaultKey,
            encryptedPayload: Data(ciphertext)
        )
        let tampered = try crypto.encode(file)
        #expect(throws: VaultError.self) {
            _ = try crypto.openVault(data: tampered, password: password)
        }
    }

    @Test func changingMasterPasswordRewrapsVaultKey() throws {
        let crypto = SodiumVaultCrypto()
        let payload = VaultPayload(savedAt: .now, entries: [PasswordEntry(title: "银行", password: "high-value-secret")])
        let sealed = try crypto.seal(crypto.createVault(password: password, payload: payload))
        let newPassword = "a different correct horse password"

        let changed = try crypto.changePassword(
            data: sealed.data,
            currentPassword: password,
            newPassword: newPassword
        )

        #expect(throws: VaultError.self) {
            _ = try crypto.openVault(data: changed.data, password: password)
        }
        let reopened = try crypto.openVault(data: changed.data, password: newPassword)
        #expect(reopened.payload.entries.first?.title == "银行")
    }
}
