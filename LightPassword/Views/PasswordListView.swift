import SwiftUI

struct PasswordListView: View {
    @EnvironmentObject private var model: AppModel
    @State private var searchText = ""
    @State private var favoritesOnly = false
    @State private var sortOrder: EntrySortOrder = .title
    @State private var editingEntry: PasswordEntry?

    private var displayedEntries: [PasswordEntry] {
        let filtered = model.entries.filter { entry in
            !entry.isDeleted && (!favoritesOnly || entry.isFavorite) && entry.matches(searchText)
        }
        return filtered.sorted { lhs, rhs in
            switch sortOrder {
            case .title:
                lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            case .createdAt:
                lhs.createdAt > rhs.createdAt
            case .updatedAt:
                lhs.updatedAt > rhs.updatedAt
            }
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if displayedEntries.isEmpty {
                    ContentUnavailableView {
                        Label(emptyTitle, systemImage: favoritesOnly ? "star" : "key")
                    } description: {
                        Text(emptyDescription)
                    } actions: {
                        if model.entries.allSatisfy(\.isDeleted) && searchText.isEmpty && !favoritesOnly {
                            Button("添加第一个密码") { editingEntry = newEntry() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                } else {
                    List {
                        ForEach(displayedEntries) { entry in
                            PasswordEntryRow(entry: entry, editingEntry: $editingEntry)
                                .accessibilityIdentifier("entry.row.\(entry.id.uuidString)")
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { model.moveToTrash(entry) } label: {
                                        Label("删除", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button { model.toggleFavorite(entry) } label: {
                                        Label(entry.isFavorite ? "取消收藏" : "收藏", systemImage: entry.isFavorite ? "star.slash" : "star")
                                    }
                                    .tint(.yellow)
                                }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("轻密码")
            .accessibilityIdentifier("passwordList")
            .searchable(text: $searchText, prompt: "搜索标题、用户名或网站")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Toggle("仅显示收藏", isOn: $favoritesOnly)
                        Picker("排序", selection: $sortOrder) {
                            ForEach(EntrySortOrder.allCases) { order in
                                Text(order.rawValue).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: favoritesOnly ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("筛选与排序")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editingEntry = newEntry() } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("添加密码")
                }
            }
            .sheet(item: $editingEntry) { entry in
                EntryEditorView(existingEntry: entry.title.isEmpty && entry.password.isEmpty ? nil : entry)
            }
        }
    }

    private var emptyTitle: String {
        if !searchText.isEmpty { return "没有搜索结果" }
        if favoritesOnly { return "还没有收藏" }
        return "还没有密码"
    }

    private var emptyDescription: String {
        if !searchText.isEmpty { return "请尝试其他关键词。" }
        if favoritesOnly { return "收藏的密码会显示在这里。" }
        return "添加账号密码后，可以从列表快速复制。"
    }

    private func newEntry() -> PasswordEntry {
        PasswordEntry(title: "", password: "")
    }
}

private struct PasswordEntryRow: View {
    @EnvironmentObject private var model: AppModel
    let entry: PasswordEntry
    @Binding var editingEntry: PasswordEntry?

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink {
                PasswordDetailView(entryID: entry.id)
            } label: {
                HStack(spacing: 12) {
                    EntryIcon(title: entry.title)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Text(entry.title)
                                .font(.headline)
                                .lineLimit(1)
                            if entry.isFavorite {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                            }
                        }
                        Text(entry.username.isEmpty ? (entry.website.isEmpty ? "未设置用户名" : entry.website) : entry.username)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if !entry.username.isEmpty {
                Button { model.copyUsername(entry) } label: {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.title3)
                        .frame(width: 30, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("复制 \(entry.title) 的用户名")
            }

            Button { model.copyPassword(entry) } label: {
                Image(systemName: "key.fill")
                    .font(.title3)
                    .frame(width: 30, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("复制 \(entry.title) 的密码")
            .accessibilityIdentifier("entry.copyPassword.\(entry.id.uuidString)")
        }
        .contextMenu {
            if !entry.username.isEmpty {
                Button { model.copyUsername(entry) } label: { Label("复制用户名", systemImage: "person.crop.circle") }
            }
            Button { model.copyPassword(entry) } label: { Label("复制密码", systemImage: "key") }
            Button { editingEntry = entry } label: { Label("编辑", systemImage: "pencil") }
            Button { model.toggleFavorite(entry) } label: {
                Label(entry.isFavorite ? "取消收藏" : "收藏", systemImage: entry.isFavorite ? "star.slash" : "star")
            }
            Divider()
            Button(role: .destructive) { model.moveToTrash(entry) } label: { Label("移到回收站", systemImage: "trash") }
        }
    }
}

struct EntryIcon: View {
    let title: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.accentColor.gradient)
                .frame(width: 42, height: 42)
            Text(String(title.trimmingCharacters(in: .whitespacesAndNewlines).first ?? "密"))
                .font(.headline.bold())
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }
}
