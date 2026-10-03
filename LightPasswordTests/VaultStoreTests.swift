import Foundation
import Testing
@testable import LightPassword

struct VaultStoreTests {
    @Test func writeReadReplaceAndDelete() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = FileVaultStore(baseDirectory: directory)

        #expect(!store.exists)
        try store.write(Data("first".utf8))
        #expect(store.exists)
        #expect(try store.read() == Data("first".utf8))

        try store.write(Data("replacement".utf8))
        #expect(try store.read() == Data("replacement".utf8))

        try store.delete()
        #expect(!store.exists)
        #expect(throws: VaultError.self) { _ = try store.read() }
    }
}
