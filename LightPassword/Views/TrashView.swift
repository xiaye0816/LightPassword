import SwiftUI

struct TrashView: View {
    @EnvironmentObject private var model: AppModel
    @State private var confirmsEmptyTrash = false
    @State private var pendingPermanentDelete: PasswordEntry?

    private var deletedEntries: [PasswordEntry] {
        model.entries.filter(\.isDeleted).sorted { ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if deletedEntries.isEmpty {
                    ContentUnavailableView("回收站为空", systemImage: "trash", description: Text("删除的密码会保留 30 天。"))
                } else {
                    List(deletedEntries) { entry in
                        HStack(spacing: 12) {
                            EntryIcon(title: entry.title)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.title).font(.headline)
                                if let deletedAt = entry.deletedAt {
                                    Text("删除于 \(deletedAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button { model.restore(entry) } label: { Label("恢复", systemImage: "arrow.uturn.backward") }
                                .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { pendingPermanentDelete = entry } label: { Label("永久删除", systemImage: "trash.slash") }
                        }
                        .contextMenu {
                            Button { model.restore(entry) } label: { Label("恢复", systemImage: "arrow.uturn.backward") }
                            Button(role: .destructive) { pendingPermanentDelete = entry } label: { Label("永久删除", systemImage: "trash.slash") }
                        }
                    }
                }
            }
            .navigationTitle("回收站")
            .toolbar {
                if !deletedEntries.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("清空", role: .destructive) { confirmsEmptyTrash = true }
                    }
                }
            }
            .confirmationDialog("永久删除回收站中的所有密码？", isPresented: $confirmsEmptyTrash) {
                Button("永久删除", role: .destructive) { model.emptyTrash() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("此操作无法撤销。")
            }
            .confirmationDialog(
                "永久删除“\(pendingPermanentDelete?.title ?? "该密码")”？",
                isPresented: Binding(
                    get: { pendingPermanentDelete != nil },
                    set: { if !$0 { pendingPermanentDelete = nil } }
                )
            ) {
                Button("永久删除", role: .destructive) {
                    if let entry = pendingPermanentDelete { model.permanentlyDelete(entry) }
                    pendingPermanentDelete = nil
                }
                Button("取消", role: .cancel) { pendingPermanentDelete = nil }
            }
        }
    }
}
