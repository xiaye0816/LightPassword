import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var masterPassword = ""
    @State private var confirmation = ""
    @State private var enableBiometrics = true
    @FocusState private var focusedField: Field?

    private enum Field { case password, confirmation }

    private var canCreate: Bool {
        masterPassword.count >= 12 && masterPassword == confirmation
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.tint)
                        Text("欢迎使用轻密码")
                            .font(.largeTitle.bold())
                        Text("密码只保存在这台设备的加密密码库中。主密码无法找回，请务必牢记。")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        SecureField("设置主密码（至少 12 个字符）", text: $masterPassword)
                            .accessibilityIdentifier("onboarding.masterPassword")
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .confirmation }
                            .textFieldStyle(.roundedBorder)

                        PasswordStrengthView(password: masterPassword)

                        SecureField("再次输入主密码", text: $confirmation)
                            .accessibilityIdentifier("onboarding.confirmation")
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmation)
                            .submitLabel(.done)
                            .textFieldStyle(.roundedBorder)

                        if !confirmation.isEmpty && confirmation != masterPassword {
                            Label("两次输入的主密码不一致", systemImage: "exclamationmark.circle")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }

                        if model.biometricsAvailable {
                            Toggle("使用 Face ID 快速解锁", isOn: $enableBiometrics)
                        }
                    }

                    Button {
                        model.setup(masterPassword: masterPassword, enableBiometrics: enableBiometrics)
                    } label: {
                        Text("创建本地密码库")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canCreate)
                    .accessibilityIdentifier("onboarding.createVault")
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PasswordStrengthView: View {
    let password: String

    private var score: Int {
        var result = 0
        if password.count >= 12 { result += 1 }
        if password.count >= 16 { result += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil,
           password.rangeOfCharacter(from: .lowercaseLetters) != nil { result += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil
            || password.rangeOfCharacter(from: .punctuationCharacters) != nil { result += 1 }
        return min(result, 4)
    }

    private var title: String {
        switch score {
        case 0, 1: "较弱"
        case 2: "一般"
        case 3: "较强"
        default: "很强"
        }
    }

    private var color: Color {
        switch score {
        case 0, 1: .red
        case 2: .orange
        case 3: .blue
        default: .green
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(index < score ? color : Color.secondary.opacity(0.2))
                    .frame(height: 5)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 34)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("主密码强度：\(title)")
    }
}
