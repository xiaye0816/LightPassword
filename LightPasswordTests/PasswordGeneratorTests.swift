import Testing
@testable import LightPassword

struct PasswordGeneratorTests {
    @Test func generatedPasswordHonorsLengthAndRequiredGroups() throws {
        let generator = SecurePasswordGenerator()
        let options = PasswordGeneratorOptions(
            length: 48,
            includesLowercase: true,
            includesUppercase: true,
            includesDigits: true,
            includesSymbols: true,
            excludesAmbiguous: true
        )

        let password = try generator.generate(options: options)
        #expect(password.count == 48)
        #expect(password.rangeOfCharacter(from: .lowercaseLetters) != nil)
        #expect(password.rangeOfCharacter(from: .uppercaseLetters) != nil)
        #expect(password.rangeOfCharacter(from: .decimalDigits) != nil)
        #expect(password.contains { "!@#$%^&*()-_=+[]{}:,.?".contains($0) })
        #expect(!password.contains { "Il1O0o|".contains($0) })
    }

    @Test func invalidOptionsAreRejected() {
        let generator = SecurePasswordGenerator()
        let options = PasswordGeneratorOptions(
            length: 11,
            includesLowercase: false,
            includesUppercase: false,
            includesDigits: false,
            includesSymbols: false,
            excludesAmbiguous: true
        )
        #expect(throws: PasswordGeneratorError.self) {
            _ = try generator.generate(options: options)
        }
    }
}
