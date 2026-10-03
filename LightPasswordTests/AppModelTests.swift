import Foundation
import SwiftUI
import Testing
@testable import LightPassword

@MainActor
struct AppModelTests {
    @Test func automaticUnlockWaitsForForegroundAndOnlyAttemptsOnce() {
        var gate = AutomaticUnlockGate()

        let backgroundAttempt = gate.shouldAttempt(isSceneActive: false)
        #expect(!backgroundAttempt)
        #expect(!gate.hasAttempted)
        let foregroundAttempt = gate.shouldAttempt(isSceneActive: true)
        #expect(foregroundAttempt)
        #expect(gate.hasAttempted)

        // Face ID temporarily makes the scene inactive, then active again.
        let faceIDInactiveAttempt = gate.shouldAttempt(isSceneActive: false)
        let faceIDActiveAttempt = gate.shouldAttempt(isSceneActive: true)
        #expect(!faceIDInactiveAttempt)
        #expect(!faceIDActiveAttempt)
    }

    @Test func privacyShieldIsVisibleOnlyOutsideActiveScene() {
        #expect(!PrivacyShieldPolicy.isVisible(for: .active))
        #expect(PrivacyShieldPolicy.isVisible(for: .inactive))
        #expect(PrivacyShieldPolicy.isVisible(for: .background))
    }

    @Test func crudClipboardTrashAndBackupRestore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "LightPasswordTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = AppPreferences(defaults: defaults)
        let clipboard = TestClipboard()
        let model = AppModel(
            store: FileVaultStore(baseDirectory: directory),
            crypto: SodiumVaultCrypto(),
            biometricStore: TestBiometricStore(),
            clipboard: clipboard,
            backupService: EncryptedBackupService(),
            preferences: preferences
        )
        let masterPassword = "correct horse battery staple"

        model.bootstrap()
        #expect(model.state == .needsSetup)
        model.setup(masterPassword: masterPassword, enableBiometrics: false)
        #expect(model.state == .unlocked)

        let first = PasswordEntry(title: "邮箱", username: "alice", password: "secret-one", website: "mail.example.com")
        #expect(model.upsert(first))
        #expect(model.entries.count == 1)
        model.copyPassword(first)
        #expect(clipboard.value == "secret-one")
        #expect(clipboard.expiration == 60)

        let backup = try #require(model.exportBackup()).data
        var corruptedBackup = backup
        corruptedBackup[corruptedBackup.index(before: corruptedBackup.endIndex)] ^= 0x01
        #expect(model.restoreBackup(data: corruptedBackup, password: masterPassword) == nil)
        #expect(model.entries.map(\.title) == ["邮箱"])

        let second = PasswordEntry(title: "论坛", password: "secret-two")
        #expect(model.upsert(second))
        #expect(model.entries.count == 2)

        let preview = model.restoreBackup(data: backup, password: masterPassword)
        #expect(preview?.activeCount == 1)
        #expect(model.entries.map(\.title) == ["邮箱"])

        let restored = try #require(model.entries.first)
        model.moveToTrash(restored)
        #expect(model.entries.first?.isDeleted == true)
        model.restore(try #require(model.entries.first))
        #expect(model.entries.first?.isDeleted == false)

        model.lock()
        #expect(model.state == .locked)
        #expect(model.entries.isEmpty)
        model.unlock(masterPassword: masterPassword)
        #expect(model.entries.first?.password == "secret-one")
    }

    @Test func backgroundImmediateAutoLock() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "LightPasswordTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = AppPreferences(defaults: defaults)
        preferences.autoLockDuration = .immediately
        let model = AppModel(
            store: FileVaultStore(baseDirectory: directory),
            crypto: SodiumVaultCrypto(),
            biometricStore: TestBiometricStore(),
            clipboard: TestClipboard(),
            backupService: EncryptedBackupService(),
            preferences: preferences
        )

        model.setup(masterPassword: "correct horse battery staple", enableBiometrics: false)
        #expect(model.state == .unlocked)
        model.handleScenePhase(.inactive)
        model.handleScenePhase(.background)
        #expect(model.state == .locked)
        #expect(model.entries.isEmpty)
        model.handleScenePhase(.active)
    }

    @Test func biometricUnlockSucceedsAndFailureStaysSilent() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "LightPasswordTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let biometricStore = TestBiometricStore()
        let model = AppModel(
            store: FileVaultStore(baseDirectory: directory),
            crypto: SodiumVaultCrypto(),
            biometricStore: biometricStore,
            clipboard: TestClipboard(),
            backupService: EncryptedBackupService(),
            preferences: AppPreferences(defaults: defaults)
        )

        model.setup(masterPassword: "correct horse battery staple", enableBiometrics: true)
        model.handleScenePhase(.inactive)
        model.lock()

        #expect(await model.unlockWithBiometrics())
        #expect(model.state == .unlocked)

        model.lock()
        biometricStore.shouldFail = true
        #expect(!(await model.unlockWithBiometrics()))
        #expect(model.state == .locked)
        #expect(model.alertMessage == nil)
    }
}

@MainActor
private final class TestClipboard: ClipboardService {
    var value: String?
    var expiration: TimeInterval?

    func copy(_ value: String, expiresAfter seconds: TimeInterval) {
        self.value = value
        self.expiration = seconds
    }
}

@MainActor
private final class TestBiometricStore: BiometricKeyStore {
    private var key: [UInt8]?
    var shouldFail = false
    func save(vaultKey: [UInt8]) throws { key = vaultKey }
    func read(reason: String) async throws -> [UInt8] {
        if shouldFail { throw VaultError.biometricFailed }
        guard let key else { throw VaultError.biometricFailed }
        return key
    }
    func delete() { key = nil }
}
