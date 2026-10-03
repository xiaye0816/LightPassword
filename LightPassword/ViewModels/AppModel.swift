import Combine
import Foundation
import LocalAuthentication
import SwiftUI

enum VaultState: Equatable {
    case booting
    case needsSetup
    case locked
    case unlocked
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var state: VaultState = .booting
    @Published private(set) var entries: [PasswordEntry] = []
    @Published var alertMessage: String?
    @Published var toastMessage: String?
    @Published private(set) var privacyShieldVisible = false
    @Published private(set) var isBiometricUnlockInProgress = false

    let preferences: AppPreferences

    private let store: VaultStore
    private let crypto: VaultCrypto
    private let biometricStore: BiometricKeyStore
    private let clipboard: ClipboardService
    private let backupService: BackupService
    private var openedVault: OpenedVault?
    private var backgroundedAt: Date?
    private var autoLockTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    init(
        store: VaultStore = FileVaultStore(),
        crypto: VaultCrypto = SodiumVaultCrypto(),
        biometricStore: BiometricKeyStore = KeychainBiometricKeyStore(),
        clipboard: ClipboardService = SystemClipboardService(),
        backupService: BackupService = EncryptedBackupService(),
        preferences: AppPreferences = AppPreferences()
    ) {
        self.store = store
        self.crypto = crypto
        self.biometricStore = biometricStore
        self.clipboard = clipboard
        self.backupService = backupService
        self.preferences = preferences
    }

    var biometricsAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func bootstrap() {
#if DEBUG
        if CommandLine.arguments.contains("-ui-testing-reset") {
            try? store.delete()
            biometricStore.delete()
            preferences.biometricEnabled = false
        }
#endif
        state = store.exists ? .locked : .needsSetup
    }

    func setup(masterPassword: String, enableBiometrics: Bool) {
        do {
            guard masterPassword.count >= 12 else {
                throw ValidationError("主密码至少需要 12 个字符。")
            }
            let opened = try crypto.createVault(password: masterPassword, payload: .empty)
            let sealed = try crypto.seal(opened)
            try store.write(sealed.data)
            openedVault = sealed.vault
            entries = sealed.vault.payload.entries
            state = .unlocked
            if enableBiometrics {
                do {
                    try biometricStore.save(vaultKey: sealed.vault.vaultKey)
                    preferences.biometricEnabled = true
                } catch {
                    preferences.biometricEnabled = false
                    showError(error)
                }
            }
        } catch {
            showError(error)
        }
    }

    func unlock(masterPassword: String) {
        do {
            let data = try store.read()
            let opened = try crypto.openVault(data: data, password: masterPassword)
            finishUnlock(opened)
        } catch {
            showError(error)
        }
    }

    @discardableResult
    func unlockWithBiometrics() async -> Bool {
        guard !isBiometricUnlockInProgress else { return false }
        isBiometricUnlockInProgress = true
        defer { isBiometricUnlockInProgress = false }

        var key: [UInt8]
        do {
            key = try await biometricStore.read(reason: "解锁轻密码")
        } catch {
            return false
        }
        defer { crypto.zero(&key) }

        let data: Data
        do {
            data = try store.read()
        } catch {
            showError(error)
            return false
        }

        do {
            let opened = try crypto.openVault(data: data, vaultKey: key)
            finishUnlock(opened)
            return true
        } catch VaultError.wrongPasswordOrCorrupted {
            return false
        } catch {
            showError(error)
            return false
        }
    }

    func lock() {
        autoLockTask?.cancel()
        guard openedVault != nil else {
            entries = []
            if store.exists { state = .locked }
            return
        }
        crypto.zero(&openedVault!.vaultKey)
        self.openedVault = nil
        entries = []
        state = store.exists ? .locked : .needsSetup
    }

    func upsert(_ entry: PasswordEntry) -> Bool {
        guard var opened = openedVault else { return false }
        var value = entry
        value.updatedAt = .now
        if let index = opened.payload.entries.firstIndex(where: { $0.id == value.id }) {
            opened.payload.entries[index] = value
        } else {
            opened.payload.entries.append(value)
        }
        return persist(opened)
    }

    func moveToTrash(_ entry: PasswordEntry) {
        mutateEntry(entry.id) { value in
            value.deletedAt = .now
            value.updatedAt = .now
        }
        showToast("已移到回收站")
    }

    func restore(_ entry: PasswordEntry) {
        mutateEntry(entry.id) { value in
            value.deletedAt = nil
            value.updatedAt = .now
        }
        showToast("已恢复")
    }

    func permanentlyDelete(_ entry: PasswordEntry) {
        guard var opened = openedVault else { return }
        opened.payload.entries.removeAll { $0.id == entry.id }
        if persist(opened) { showToast("已永久删除") }
    }

    func emptyTrash() {
        guard var opened = openedVault else { return }
        opened.payload.entries.removeAll { $0.isDeleted }
        if persist(opened) { showToast("回收站已清空") }
    }

    func toggleFavorite(_ entry: PasswordEntry) {
        mutateEntry(entry.id) { value in
            value.isFavorite.toggle()
            value.updatedAt = .now
        }
    }

    func copyUsername(_ entry: PasswordEntry) {
        guard !entry.username.isEmpty else {
            showToast("该条目没有用户名")
            return
        }
        clipboard.copy(entry.username, expiresAfter: TimeInterval(preferences.clipboardDuration))
        showToast("用户名已复制")
    }

    func copyPassword(_ entry: PasswordEntry) {
        clipboard.copy(entry.password, expiresAfter: TimeInterval(preferences.clipboardDuration))
        showToast("密码已复制，\(preferences.clipboardDuration) 秒后清除")
    }

    func copyGeneratedPassword(_ password: String) {
        guard !password.isEmpty else { return }
        clipboard.copy(password, expiresAfter: TimeInterval(preferences.clipboardDuration))
        showToast("密码已复制，\(preferences.clipboardDuration) 秒后清除")
    }

    func exportBackup() -> VaultBackupDocument? {
        do {
            return VaultBackupDocument(data: try backupService.exportData(from: store))
        } catch {
            showError(error)
            return nil
        }
    }

    func inspectBackup(data: Data, password: String) throws -> BackupPreview {
        try backupService.preview(data: data, password: password, crypto: crypto)
    }

    func restoreBackup(data: Data, password: String) -> BackupPreview? {
        do {
            let preview = try inspectBackup(data: data, password: password)
            let restored = try crypto.openVault(data: data, password: password)
            try store.write(data)
            if openedVault != nil { crypto.zero(&openedVault!.vaultKey) }
            openedVault = restored
            entries = restored.payload.entries
            if preferences.biometricEnabled {
                try biometricStore.save(vaultKey: restored.vaultKey)
            }
            showToast("备份已恢复")
            return preview
        } catch {
            showError(error)
            return nil
        }
    }

    func changeMasterPassword(current: String, new: String) -> Bool {
        do {
            guard new.count >= 12 else { throw ValidationError("新主密码至少需要 12 个字符。") }
            let changed = try crypto.changePassword(
                data: store.read(),
                currentPassword: current,
                newPassword: new
            )
            try store.write(changed.data)
            if openedVault != nil { crypto.zero(&openedVault!.vaultKey) }
            openedVault = changed.vault
            entries = changed.vault.payload.entries
            if preferences.biometricEnabled {
                try biometricStore.save(vaultKey: changed.vault.vaultKey)
            }
            showToast("主密码已修改")
            return true
        } catch {
            showError(error)
            return false
        }
    }

    func setBiometricEnabled(_ enabled: Bool) -> Bool {
        guard let openedVault else { return false }
        do {
            if enabled {
                try biometricStore.save(vaultKey: openedVault.vaultKey)
            } else {
                biometricStore.delete()
            }
            preferences.biometricEnabled = enabled
            return true
        } catch {
            preferences.biometricEnabled = false
            showError(error)
            return false
        }
    }

    func eraseVault(masterPassword: String) -> Bool {
        do {
            _ = try crypto.openVault(data: store.read(), password: masterPassword)
            try store.delete()
            biometricStore.delete()
            preferences.biometricEnabled = false
            lock()
            state = .needsSetup
            showToast("本地密码库已删除")
            return true
        } catch {
            showError(error)
            return false
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            autoLockTask?.cancel()
            if let backgroundedAt,
               Date().timeIntervalSince(backgroundedAt) >= TimeInterval(preferences.autoLockDuration.rawValue) {
                lock()
            }
            backgroundedAt = nil
            privacyShieldVisible = false
        case .inactive:
            privacyShieldVisible = true
        case .background:
            privacyShieldVisible = true
            backgroundedAt = .now
            scheduleAutoLock()
        @unknown default:
            privacyShieldVisible = true
        }
    }

    func protectedDataWillBecomeUnavailable() {
        privacyShieldVisible = true
        lock()
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }

    private func finishUnlock(_ opened: OpenedVault) {
        openedVault = opened
        entries = opened.payload.entries
        privacyShieldVisible = false
        state = .unlocked
        purgeExpiredTrash()
    }

    private func mutateEntry(_ id: UUID, mutation: (inout PasswordEntry) -> Void) {
        guard var opened = openedVault,
              let index = opened.payload.entries.firstIndex(where: { $0.id == id }) else { return }
        mutation(&opened.payload.entries[index])
        _ = persist(opened)
    }

    @discardableResult
    private func persist(_ opened: OpenedVault) -> Bool {
        do {
            let sealed = try crypto.seal(opened)
            try store.write(sealed.data)
            openedVault = sealed.vault
            entries = sealed.vault.payload.entries
            return true
        } catch {
            showError(error)
            return false
        }
    }

    private func purgeExpiredTrash() {
        guard var opened = openedVault else { return }
        let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let originalCount = opened.payload.entries.count
        opened.payload.entries.removeAll { entry in
            guard let deletedAt = entry.deletedAt else { return false }
            return deletedAt < cutoff
        }
        if opened.payload.entries.count != originalCount { _ = persist(opened) }
    }

    private func scheduleAutoLock() {
        autoLockTask?.cancel()
        let duration = preferences.autoLockDuration.rawValue
        if duration == 0 {
            lock()
            return
        }
        autoLockTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            self?.lock()
        }
    }

    private func showError(_ error: Error) {
        alertMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}

private struct ValidationError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
