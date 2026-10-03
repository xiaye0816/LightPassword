import SwiftUI

struct PasswordDetailView: View {
    @EnvironmentObject private var model: AppModel
    let entryID: UUID
    @State private var revealsPassword = false
    @State private var showsEditor = false
    @State private var confirmsDelete = false

    private var entry: PasswordEntry? {
        model.entries.first { $0.id == entryID }
    }

    var body: some View {
        Group {
            if let entry {
                List {
                    Section {
                        HStack(spacing: 14) {
                            EntryIcon(title: entry.title)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.title).font(.title3.bold())
                                if !entry.website.isEmpty {
                                    Text(entry.website).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    if !entry.username.isEmpty {
                        Section("用户名") {
                            CopyableValueRow(value: entry.username, icon: "person.crop.circle") {
                                model.copyUsername(entry)
                            }
                        }
                    }

                    Section("密码") {
                        HStack {
                            Text(revealsPassword ? entry.password : String(repeating: "•", count: min(max(entry.password.count, 8), 20)))
                                .font(.body.monospaced())
                                .lineLimit(1)
                            Spacer()
                            Button { revealsPassword.toggle() } label: {
                                Image(systemName: revealsPassword ? "eye.slash" : "eye")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(revealsPassword ? "隐藏密码" : "显示密码")
                            .accessibilityIdentifier("passwordDetail.revealPassword")
                            Button { model.copyPassword(entry) } label: {
                                Image(systemName: "doc.on.doc")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("复制密码")
                            .accessibilityIdentifier("passwordDetail.copyPassword")
                        }
                    }

                    if !entry.notes.isEmpty {
                        Section("备注") {
                            Text(entry.notes)
                                .textSelection(.enabled)
                        }
                    }

                    Section("信息") {
                        LabeledContent("创建时间", value: entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("修改时间", value: entry.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    }

                    Section {
                        Button("移到回收站", systemImage: "trash", role: .destructive) {
                            confirmsDelete = true
                        }
                    }
                }
                .navigationTitle("密码详情")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("编辑") { showsEditor = true }
                    }
                }
                .sheet(isPresented: $showsEditor) {
                    EntryEditorView(existingEntry: entry)
                }
                .confirmationDialog("将“\(entry.title)”移到回收站？", isPresented: $confirmsDelete) {
                    Button("移到回收站", role: .destructive) { model.moveToTrash(entry) }
                    Button("取消", role: .cancel) {}
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    revealsPassword = false
                }
            } else {
                ContentUnavailableView("密码不存在", systemImage: "questionmark.folder")
            }
        }
    }
}

private struct CopyableValueRow: View {
    let value: String
    let icon: String
    let action: () -> Void

    var body: some View {
        HStack {
            Label(value, systemImage: icon)
                .textSelection(.enabled)
            Spacer()
            Button(action: action) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("复制")
        }
    }
}
