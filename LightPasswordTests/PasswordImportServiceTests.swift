import Foundation
import Testing
@testable import LightPassword

struct PasswordImportServiceTests {
    private let service = CSVPasswordImportService()

    @Test func parsesOnePasswordCSVIncludingQuotesBOMAndMultilineNotes() throws {
        let csv = "Title,Url,Username,Password,Extra,Grouping,Fav\n"
            + "\"Mail, Personal\",https://mail.example.com,alice,\"p\"\"ass\",\"first line\nsecond line\",Work,1\r\n"
            + ",https://forum.example.com,bob,secret,,,\n"
            + "No password,https://empty.example.com,charlie,,,Home,0\r\n"

        let preview = try service.preview(data: Data(csv.utf8), sourceFilename: "data.csv")

        #expect(preview.sourceFilename == "data.csv")
        #expect(preview.importableCount == 2)
        #expect(preview.skippedEmptyPasswordLines == [5])
        #expect(preview.unsupportedFields == ["Grouping"])
        #expect(preview.candidates[0] == ImportedPasswordCandidate(
            title: "Mail, Personal",
            username: "alice",
            password: "p\"ass",
            website: "https://mail.example.com",
            notes: "first line\nsecond line",
            isFavorite: true
        ))
        #expect(preview.candidates[1].title == "https://forum.example.com")
        #expect(preview.candidates[1].password == "secret")
    }

    @Test func acceptsUTF8BOMAndCRLF() throws {
        let csv = "\u{feff}Title,Password\r\nMail,secret\r\n"
        let preview = try service.preview(data: Data(csv.utf8), sourceFilename: "data.csv")
        #expect(preview.importableCount == 1)
        #expect(preview.candidates[0].title == "Mail")
    }

    @Test func acceptsChineseHeadersAndPreservesPasswordWhitespace() throws {
        let csv = "标题,账号,密码,网站,备注,收藏\n测试,用户, 口令 ,example.com,备注,是"
        let preview = try service.preview(data: Data(csv.utf8), sourceFilename: "中文.csv")

        #expect(preview.importableCount == 1)
        #expect(preview.candidates[0].password == " 口令 ")
        #expect(preview.candidates[0].isFavorite)
    }

    @Test func rejectsInvalidInputAndEnforcesLimits() throws {
        assertError(.emptyFile, data: Data("\n\r\n".utf8))
        assertError(.missingPasswordColumn, data: Data("Title,Username\nMail,alice".utf8))
        assertError(.malformedCSV(line: 2), data: Data("Title,Password\nMail,\"unterminated".utf8))
        assertError(.unsupportedEncoding, data: Data([0xff, 0xfe, 0xfd]))
        assertError(.fileTooLarge, data: Data(repeating: 0x61, count: CSVPasswordImportService.maximumFileSize + 1))

        let rows = Array(repeating: "Mail,secret", count: CSVPasswordImportService.maximumRowCount + 1)
        let oversizedRows = "Title,Password\n" + rows.joined(separator: "\n")
        assertError(.tooManyRows, data: Data(oversizedRows.utf8))
    }

    private func assertError(_ expected: PasswordImportError, data: Data) {
        do {
            _ = try service.preview(data: data, sourceFilename: "test.csv")
            Issue.record("预期抛出 \(expected)")
        } catch let error as PasswordImportError {
            #expect(error == expected)
        } catch {
            Issue.record("错误类型不正确：\(error)")
        }
    }
}
