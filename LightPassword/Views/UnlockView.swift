import SwiftUI

struct UnlockView: View {
    @EnvironmentObject private var model: AppModel
    @State private var password = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("轻密码")
                    .font(.largeTitle.bold())
                Text("解锁本地密码库")
                    .foregroundStyle(.secondary)

                SecureField("主密码", text: $password)
                    .textContentType(.password)
                    .focused($isFocused)
                    .submitLabel(.go)
                    .onSubmit(unlock)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 420)

                Button(action: unlock) {
                    Text("解锁")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(password.isEmpty)
                .frame(maxWidth: 420)

                if model.preferences.biometricEnabled {
                    Button {
                        Task { await model.unlockWithBiometrics() }
                    } label: {
                        Label("使用 Face ID", systemImage: "faceid")
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
            }
            .padding(24)
            .onAppear {
                if model.preferences.biometricEnabled {
                    Task { await model.unlockWithBiometrics() }
                } else {
                    isFocused = true
                }
            }
        }
    }

    private func unlock() {
        model.unlock(masterPassword: password)
        password = ""
    }
}
