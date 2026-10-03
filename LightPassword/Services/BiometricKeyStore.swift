import Foundation
import LocalAuthentication
import Security

@MainActor
protocol BiometricKeyStore {
    func save(vaultKey: [UInt8]) throws
    func read(reason: String) async throws -> [UInt8]
    func delete()
}

@MainActor
final class KeychainBiometricKeyStore: BiometricKeyStore {
    private let service = "com.shaoguoqing.lightpassword.vault"
    private let account = "vault-key"

    func save(vaultKey: [UInt8]) throws {
        delete()
        var accessError: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            &accessError
        ) else {
            throw VaultError.biometricUnavailable
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessControl as String: access,
            kSecValueData as String: Data(vaultKey),
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw VaultError.biometricUnavailable
        }
    }

    func read(reason: String) async throws -> [UInt8] {
        let context = LAContext()
        context.localizedCancelTitle = "使用主密码"
        context.localizedReason = reason
        return try await withCheckedThrowingContinuation { continuation in
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecReturnData as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
                kSecUseAuthenticationContext as String: context,
            ]
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess, let data = result as? Data else {
                continuation.resume(throwing: VaultError.biometricFailed)
                return
            }
            continuation.resume(returning: Array(data))
        }
    }

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
