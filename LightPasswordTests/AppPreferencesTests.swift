import Foundation
import Testing
@testable import LightPassword

@MainActor
struct AppPreferencesTests {
    @Test func generatorDefaultsAndSelectionsPersist() throws {
        let suiteName = "LightPasswordTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let initial = AppPreferences(defaults: defaults).generatorOptions
        #expect(initial.length == 16)
        #expect(initial.includesLowercase)
        #expect(initial.includesUppercase)
        #expect(initial.includesDigits)
        #expect(!initial.includesSymbols)
        #expect(initial.excludesAmbiguous)

        let customized = PasswordGeneratorOptions(
            length: 37,
            includesLowercase: false,
            includesUppercase: true,
            includesDigits: false,
            includesSymbols: true,
            excludesAmbiguous: false
        )
        AppPreferences(defaults: defaults).generatorOptions = customized

        #expect(AppPreferences(defaults: defaults).generatorOptions == customized)
    }
}
