import SwiftUI

struct EntryEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    private let existingEntry: PasswordEntry?

    @State private var title: String
    @State private var username: String
    @State private var password: String
    @State private var website: String
    @State private var notes: String
    @State private var isFavorite: Bool
    @State private var revealsPassword = false
    @State private var showsGenerator = false

    init(existingEntry: PasswordEntry?) {
        self.existingEntry = existingEntry
        _title = State(initialValue: existingEntry?.title ?? "")
        _username = State(initialValue: existingEntry?.username ?? "")
        _password = State(initialValue: existingEntry?.password ?? "")
        _website = State(initialValue: existingEntry?.website ?? "")
        _notes = State(initialValue: existingEntry?.notes ?? "")
        _isFavorite = State(initialValue: existingEntry?.isFavorite ?? false)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("基本信息") {
                    TextField("标题", text: $title)
                        .textContentType(.name)
                        .accessibilityIdentifier("entryEditor.title")
                    TextField("用户名（可选）", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                        .accessibilityIdentifier("entryEditor.username")
                    TextField("网站或 App 名称（可选）", text: $website)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }

                Section("密码") {
                    HStack {
                        Group {
                            if revealsPassword {
                                TextField("密码", text: $password)
                            } else {
                                SecureField("密码", text: $password)
                            }
                        }
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityIdentifier("entryEditor.password")

                        Button { revealsPassword.toggle() } label: {
                            Image(systemName: revealsPassword ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(revealsPassword ? "隐藏密码" : "显示密码")
                    }
                    Button { showsGenerator = true } label: {
                        Label("生成安全密码", systemImage: "wand.and.stars")
                    }
                }

                Section("备注") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 90)
                }

                Section {
                    Toggle("收藏", isOn: $isFavorite)
                }
            }
            .navigationTitle(existingEntry == nil ? "添加密码" : "编辑密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save)
                        .disabled(!canSave)
                        .accessibilityIdentifier("entryEditor.save")
                }
            }
            .sheet(isPresented: $showsGenerator) {
                PasswordGeneratorView { generated in
                    password = generated
                    revealsPassword = true
                    showsGenerator = false
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                revealsPassword = false
            }
        }
    }

    private func save() {
        let now = Date.now
        let entry = PasswordEntry(
            id: existingEntry?.id ?? UUID(),
            title: title,
            username: username,
            password: password,
            website: website,
            notes: notes,
            isFavorite: isFavorite,
            createdAt: existingEntry?.createdAt ?? now,
            updatedAt: now,
            deletedAt: existingEntry?.deletedAt
        )
        if model.upsert(entry) {
            model.showToast(existingEntry == nil ? "密码已添加" : "修改已保存")
            dismiss()
        }
    }
}
