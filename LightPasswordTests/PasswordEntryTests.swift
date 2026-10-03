import Testing
@testable import LightPassword

struct PasswordEntryTests {
    @Test func searchCoversTitleUsernameAndWebsite() {
        let entry = PasswordEntry(
            title: "工作邮箱",
            username: "Alice@Example.com",
            password: "secret",
            website: "mail.example.com"
        )
        #expect(entry.matches("工作"))
        #expect(entry.matches("alice"))
        #expect(entry.matches("MAIL.EXAMPLE"))
        #expect(!entry.matches("bank"))
    }
}
