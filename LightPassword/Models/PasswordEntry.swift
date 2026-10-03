import Foundation

struct PasswordEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var username: String
    var password: String
    var website: String
    var notes: String
    var isFavorite: Bool
    let createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        username: String = "",
        password: String,
        website: String = "",
        notes: String = "",
        isFavorite: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.password = password
        self.website = website.trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = notes
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    var isDeleted: Bool { deletedAt != nil }

    func matches(_ query: String) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }
        return title.localizedCaseInsensitiveContains(term)
            || username.localizedCaseInsensitiveContains(term)
            || website.localizedCaseInsensitiveContains(term)
    }
}

enum EntrySortOrder: String, CaseIterable, Identifiable {
    case title = "标题"
    case createdAt = "创建时间"
    case updatedAt = "修改时间"

    var id: String { rawValue }
}
