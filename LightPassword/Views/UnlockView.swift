import SwiftUI

struct AutomaticUnlockGate {
    private(set) var hasAttempted = false

    mutating func shouldAttempt(isSceneActive: Bool) -> Bool {
        guard isSceneActive, !hasAttempted else { return false }
        hasAttempted = true
        return true
    }
}

struct UnlockView: View {
    private enum PresentationState: Equatable {
        case biometricAuthenticating
        case passwordFallback
    }

    @EnvironmentObject private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var password = ""
    @State private var presentationState: PresentationState = .biometricAuthenticating
    @State private var automaticUnlockGate = AutomaticUnlockGate()
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
                if presentationState == .biometricAuthenticating {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("正在验证 Face ID…")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("unlock.biometricProgress")
                } else {
                    Text("解锁本地密码库")
                        .foregroundStyle(.secondary)

                    SecureField("主密码", text: $password)
                        .textContentType(.password)
                        .focused($isFocused)
                        .submitLabel(.go)
                        .onSubmit(unlock)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 420)
                        .accessibilityIdentifier("unlock.masterPassword")

                    Button(action: unlock) {
                        Text("解锁")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(password.isEmpty)
                    .frame(maxWidth: 420)

                    if model.preferences.biometricEnabled {
                        Button(action: startBiometricUnlock) {
                            Label("使用 Face ID", systemImage: "faceid")
                        }
                        .buttonStyle(.bordered)
                        .disabled(model.isBiometricUnlockInProgress)
                        .accessibilityIdentifier("unlock.retryFaceID")
                    }
                }
                Spacer()
            }
            .padding(24)
            .onAppear {
                startAutomaticUnlockIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                startAutomaticUnlockIfNeeded()
            }
        }
    }

    private func startAutomaticUnlockIfNeeded() {
        guard automaticUnlockGate.shouldAttempt(isSceneActive: scenePhase == .active) else { return }
        if model.preferences.biometricEnabled && model.biometricsAvailable {
            startBiometricUnlock()
        } else {
            presentationState = .passwordFallback
            isFocused = true
        }
    }

    private func unlock() {
        model.unlock(masterPassword: password)
        password = ""
    }

    private func startBiometricUnlock() {
        guard !model.isBiometricUnlockInProgress else { return }
        isFocused = false
        presentationState = .biometricAuthenticating
        Task {
            let succeeded = await model.unlockWithBiometrics()
            guard !succeeded, model.state == .locked else { return }
            presentationState = .passwordFallback
            isFocused = true
        }
    }
}
