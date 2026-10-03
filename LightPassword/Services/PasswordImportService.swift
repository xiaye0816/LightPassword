import Foundation

struct ImportedPasswordCandidate: Equatable, Sendable {
    let title: String
    let username: String
    let password: String
    let website: String
    let notes: String
    let isFavorite: Bool
}

struct PasswordImportPreview: Equatable, Sendable {
    let sourceFilename: String
    let candidates: [ImportedPasswordCandidate]
    let skippedEmptyPasswordLines: [Int]
    let unsupportedFields: [String]

    var importableCount: Int { candidates.count }
    var skippedCount: Int { skippedEmptyPasswordLines.count }
}

enum PasswordImportError: LocalizedError, Equatable {
    case fileTooLarge
    case unsupportedEncoding
    case emptyFile
    case tooManyRows
    case malformedCSV(line: Int)
    case missingPasswordColumn

    var errorDescription: String? {
        switch self {
        case .fileTooLarge: "CSV 文件超过 20 MB，无法导入。"
        case .unsupportedEncoding: "CSV 必须使用 UTF-8 编码。"
        case .emptyFile: "CSV 文件中没有可读取的内容。"
        case .tooManyRows: "CSV 超过 50,000 行，无法导入。"
        case let .malformedCSV(line): "CSV 第 \(line) 行格式不正确。"
        case .missingPasswordColumn: "CSV 中缺少 Password（密码）列。"
        }
    }
}

protocol PasswordImporting {
    func preview(data: Data, sourceFilename: String) throws -> PasswordImportPreview
}

struct CSVPasswordImportService: PasswordImporting {
    static let maximumFileSize = 20 * 1_024 * 1_024
    static let maximumRowCount = 50_000

    func preview(data: Data, sourceFilename: String) throws -> PasswordImportPreview {
        guard data.count <= Self.maximumFileSize else { throw PasswordImportError.fileTooLarge }
        guard var text = String(data: data, encoding: .utf8) else {
            throw PasswordImportError.unsupportedEncoding
        }
        if text.first == "\u{feff}" { text.removeFirst() }

        let records = try CSVParser.parse(text)
        guard let headerRecord = records.first(where: { !$0.fields.allSatisfy(isBlank) }) else {
            throw PasswordImportError.emptyFile
        }
        let dataRecords = records.drop(while: { $0.line != headerRecord.line }).dropFirst()
        guard dataRecords.count <= Self.maximumRowCount else { throw PasswordImportError.tooManyRows }

        let headers = headerRecord.fields.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let normalizedHeaders = headers.map(normalizeHeader)
        guard let passwordIndex = firstIndex(of: ["password", "pass", "密码"], in: normalizedHeaders) else {
            throw PasswordImportError.missingPasswordColumn
        }

        let titleIndex = firstIndex(of: ["title", "标题"], in: normalizedHeaders)
            ?? firstIndex(of: ["name", "名称"], in: normalizedHeaders)
        let usernameIndex = firstIndex(of: ["username", "user", "login", "用户名", "账号"], in: normalizedHeaders)
        let websiteIndex = firstIndex(of: ["url", "website", "site", "网址", "网站"], in: normalizedHeaders)
        let notesIndex = firstIndex(of: ["notes", "note", "extra", "备注"], in: normalizedHeaders)
        let favoriteIndex = firstIndex(of: ["favorite", "favourite", "fav", "收藏"], in: normalizedHeaders)
        let mappedIndices = Set([titleIndex, usernameIndex, websiteIndex, notesIndex, favoriteIndex, passwordIndex].compactMap { $0 })

        var candidates: [ImportedPasswordCandidate] = []
        var skippedLines: [Int] = []
        var unsupportedIndices = Set<Int>()
        var unnamedUnsupportedIndices = Set<Int>()

        for record in dataRecords where !record.fields.allSatisfy(isBlank) {
            let password = value(at: passwordIndex, in: record.fields)
            guard !password.isEmpty else {
                skippedLines.append(record.line)
                continue
            }

            let username = value(at: usernameIndex, in: record.fields)
            let website = value(at: websiteIndex, in: record.fields)
            let rawTitle = value(at: titleIndex, in: record.fields).trimmingCharacters(in: .whitespacesAndNewlines)
            let title = rawTitle.isEmpty
                ? fallbackTitle(website: website, username: username)
                : rawTitle

            candidates.append(ImportedPasswordCandidate(
                title: title,
                username: username,
                password: password,
                website: website,
                notes: value(at: notesIndex, in: record.fields),
                isFavorite: parseFavorite(value(at: favoriteIndex, in: record.fields))
            ))

            for index in headers.indices where !mappedIndices.contains(index) {
                if !value(at: index, in: record.fields).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    unsupportedIndices.insert(index)
                }
            }
            for index in record.fields.indices where index >= headers.count {
                if !record.fields[index].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    unnamedUnsupportedIndices.insert(index)
                }
            }
        }

        let namedUnsupportedFields = unsupportedIndices.sorted().map {
            headers[$0].isEmpty ? "第 \($0 + 1) 列" : headers[$0]
        }
        let unnamedUnsupportedFields = unnamedUnsupportedIndices.sorted().map { "第 \($0 + 1) 列" }

        return PasswordImportPreview(
            sourceFilename: sourceFilename,
            candidates: candidates,
            skippedEmptyPasswordLines: skippedLines,
            unsupportedFields: namedUnsupportedFields + unnamedUnsupportedFields
        )
    }

    private func normalizeHeader(_ header: String) -> String {
        header
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }

    private func firstIndex(of aliases: [String], in headers: [String]) -> Int? {
        let normalizedAliases = aliases.map(normalizeHeader)
        for alias in normalizedAliases {
            if let index = headers.firstIndex(of: alias) { return index }
        }
        return nil
    }

    private func value(at index: Int?, in fields: [String]) -> String {
        guard let index, fields.indices.contains(index) else { return "" }
        return fields[index]
    }

    private func fallbackTitle(website: String, username: String) -> String {
        let website = website.trimmingCharacters(in: .whitespacesAndNewlines)
        if !website.isEmpty { return website }
        let username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return username.isEmpty ? "未命名导入项" : username
    }

    private func parseFavorite(_ value: String) -> Bool {
        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "y", "favorite", "favourite", "是": true
        default: false
        }
    }

    private func isBlank(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private struct CSVRecord {
    let line: Int
    let fields: [String]
}

private enum CSVParser {
    static func parse(_ text: String) throws -> [CSVRecord] {
        var records: [CSVRecord] = []
        var fields: [String] = []
        var field = ""
        var line = 1
        var recordLine = 1
        var isQuoted = false
        var didCloseQuote = false
        var index = text.startIndex

        func finishField() {
            fields.append(field)
            field.removeAll(keepingCapacity: true)
            didCloseQuote = false
        }

        func finishRecord() {
            finishField()
            records.append(CSVRecord(line: recordLine, fields: fields))
            fields.removeAll(keepingCapacity: true)
            recordLine = line
        }

        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)

            if isQuoted {
                if character == "\"" {
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = text.index(after: next)
                        continue
                    }
                    isQuoted = false
                    didCloseQuote = true
                } else {
                    field.append(character)
                    if character == "\n" || character == "\r" || character == "\r\n" { line += 1 }
                }
                index = next
                continue
            }

            if didCloseQuote {
                if character == "," {
                    finishField()
                } else if character == "\n" {
                    line += 1
                    finishRecord()
                    recordLine = line
                } else if character == "\r\n" {
                    line += 1
                    finishRecord()
                    recordLine = line
                } else if character == "\r" {
                    finishRecord()
                    if next < text.endIndex, text[next] == "\n" {
                        index = text.index(after: next)
                    } else {
                        index = next
                    }
                    line += 1
                    recordLine = line
                    continue
                } else if character != " " && character != "\t" {
                    throw PasswordImportError.malformedCSV(line: line)
                }
                index = next
                continue
            }

            switch character {
            case "\"":
                guard field.isEmpty else { throw PasswordImportError.malformedCSV(line: line) }
                isQuoted = true
            case ",":
                finishField()
            case "\n":
                line += 1
                finishRecord()
                recordLine = line
            case "\r\n":
                line += 1
                finishRecord()
                recordLine = line
            case "\r":
                finishRecord()
                if next < text.endIndex, text[next] == "\n" {
                    index = text.index(after: next)
                } else {
                    index = next
                }
                line += 1
                recordLine = line
                continue
            default:
                field.append(character)
            }
            index = next
        }

        guard !isQuoted else { throw PasswordImportError.malformedCSV(line: recordLine) }
        if !field.isEmpty || !fields.isEmpty || didCloseQuote {
            finishRecord()
        }
        return records
    }
}
