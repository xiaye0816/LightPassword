import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        SettingsContent(model: model, preferences: model.preferences)
    }
}

private struct SettingsContent: View {
    @ObservedObject var model: AppModel
    @ObservedObject var preferences: AppPreferences

    @State private var backupDocument: VaultBackupDocument?
    @State private var showsExporter = false
    @State private var showsImporter = false
    @State private var pendingRestoreData: Data?
    @State private var showsRestoreSheet = false
    @State private var showsChangePassword = false
    @State private var showsEraseVault = false

    var body: some View {
        NavigationStack {
            Form {
                Section("安全") {
                    Picker("自动锁定", selection: $preferences.autoLockDuration) {
                        ForEach(AutoLockDuration.allCases) { duration in
                            Text(duration.title).tag(duration)
                        }
                    }

                    if model.biometricsAvailable || preferences.biometricEnabled {
                        Toggle("Face ID 快速解锁", isOn: Binding(
                            get: { preferences.biometricEnabled },
                            set: { _ = model.setBiometricEnabled($0) }
                        ))
                    }

                    Button("修改主密码", systemImage: "lock.rotation") {
                        showsChangePassword = true
                    }
                    Button("立即锁定", systemImage: "lock.fill") {
                        model.lock()
                    }
                }

                Section("快捷复制") {
                    Picker("剪贴板清除时间", selection: $preferences.clipboardDuration) {
                        Text("15 秒").tag(15)
                        Text("30 秒").tag(30)
                        Text("60 秒").tag(60)
                    }
                    Text("复制内容仅保留在本机，不通过通用剪贴板同步到其他设备。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("加密备份") {
                    Button("导出加密备份", systemImage: "square.and.arrow.up") {
                        backupDocument = model.exportBackup()
                        showsExporter = backupDocument != nil
                    }
                    Button("从备份恢复", systemImage: "square.and.arrow.down") {
                        showsImporter = true
                    }
                    Text("备份使用导出时的主密码保护。恢复会完整替换当前密码库。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("关于") {
                    LabeledContent("名称", value: "轻密码")
                    LabeledContent("版本", value: "1.0")
                    LabeledContent("存储", value: "仅限本机")
                }

                Section {
                    Button("永久删除本地密码库", systemImage: "exclamationmark.triangle", role: .destructive) {
                        showsEraseVault = true
                    }
                } footer: {
                    Text("删除后只能通过已有加密备份恢复。")
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showsChangePassword) {
                ChangeMasterPasswordSheet()
            }
            .sheet(isPresented: $showsEraseVault) {
                EraseVaultSheet()
            }
            .sheet(isPresented: $showsRestoreSheet, onDismiss: { pendingRestoreData = nil }) {
                if let pendingRestoreData {
                    RestoreBackupSheet(data: pendingRestoreData)
                }
            }
            .fileExporter(
                isPresented: $showsExporter,
                document: backupDocument,
                contentType: .vaultBackup,
                defaultFilename: backupFilename
            ) { result in
                backupDocument = nil
                switch result {
                case .success:
                    model.showToast("加密备份已导出")
                case let .failure(error):
                    model.alertMessage = error.localizedDescription
                }
            }
            .fileImporter(
                isPresented: $showsImporter,
                allowedContentTypes: [.vaultBackup, .data],
                allowsMultipleSelection: false
            ) { result in
                importBackup(result)
            }
        }
    }

    private var backupFilename: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "轻密码-\(formatter.string(from: .now)).vaultbackup"
    }

    private func importBackup(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            pendingRestoreData = try Data(contentsOf: url)
            showsRestoreSheet = true
        } catch {
            model.alertMessage = error.localizedDescription
        }
    }
}

private struct ChangeMasterPasswordSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var newPassword = ""
    @State private var confirmation = ""

    private var canSubmit: Bool {
        !current.isEmpty && newPassword.count >= 12 && newPassword == confirmation
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("验证身份") {
                    SecureField("当前主密码", text: $current)
                        .textContentType(.password)
                }
                Section("新主密码") {
                    SecureField("至少 12 个字符", text: $newPassword)
                        .textContentType(.newPassword)
                    PasswordStrengthView(password: newPassword)
                    SecureField("再次输入新主密码", text: $confirmation)
                        .textContentType(.newPassword)
                    if !confirmation.isEmpty && newPassword != confirmation {
                        Text("两次输入不一致").foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("修改主密码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("修改") {
                        if model.changeMasterPassword(current: current, new: newPassword) { dismiss() }
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }
}

private struct RestoreBackupSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let data: Data

    @State private var password = ""
    @State private var preview: BackupPreview?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("备份主密码") {
                    SecureField("输入导出备份时的主密码", text: $password)
                        .textContentType(.password)
                    Button("验证备份", action: inspect)
                        .disabled(password.isEmpty)
                }

                if let preview {
                    Section("备份内容") {
                        LabeledContent("保存时间", value: preview.savedAt.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("有效密码", value: "\(preview.activeCount)")
                        LabeledContent("回收站", value: "\(preview.deletedCount)")
                    }
                    Section {
                        Button("替换当前密码库", role: .destructive) {
                            if model.restoreBackup(data: data, password: password) != nil { dismiss() }
                        }
                    } footer: {
                        Text("当前密码库会被完整替换，此操作无法合并。")
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("恢复加密备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }

    private func inspect() {
        do {
            preview = try model.inspectBackup(data: data, password: password)
            errorMessage = nil
        } catch {
            preview = nil
            errorMessage = error.localizedDescription
        }
    }
}

private struct EraseVaultSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("此操作会永久删除这台设备上的全部密码。请先确认已经导出可用的加密备份。")
                        .foregroundStyle(.red)
                }
                Section("确认") {
                    SecureField("主密码", text: $password)
                    TextField("输入“永久删除”", text: $confirmation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Button("永久删除", role: .destructive) {
                        if model.eraseVault(masterPassword: password) { dismiss() }
                    }
                    .disabled(password.isEmpty || confirmation != "永久删除")
                }
            }
            .navigationTitle("删除密码库")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
            }
        }
    }
}
