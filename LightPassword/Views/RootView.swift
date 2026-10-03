import SwiftUI

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Group {
                switch model.state {
                case .booting:
                    ProgressView("正在打开轻密码…")
                case .needsSetup:
                    OnboardingView()
                case .locked:
                    UnlockView()
                case .unlocked:
                    MainTabView()
                }
            }

            if let toast = model.toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.black.opacity(0.82), in: Capsule())
                        .padding(.bottom, 42)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.easeInOut, value: toast)
                .allowsHitTesting(false)
            }

            if model.privacyShieldVisible {
                PrivacyShieldView()
                    .transition(.opacity)
                    .zIndex(10)
            }
        }
        .alert("轻密码", isPresented: Binding(
            get: { model.alertMessage != nil },
            set: { if !$0 { model.alertMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { model.alertMessage = nil }
        } message: {
            Text(model.alertMessage ?? "发生未知错误。")
        }
    }
}

private struct PrivacyShieldView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                Text("轻密码")
                    .font(.title2.bold())
                Text("密码库内容已隐藏")
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("轻密码已隐藏密码库内容")
        .accessibilityIdentifier("privacyShield")
    }
}
