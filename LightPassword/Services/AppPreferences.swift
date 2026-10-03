import Combine
import Foundation

enum AutoLockDuration: Int, CaseIterable, Identifiable {
    case immediately = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900

    var id: Int { rawValue }
    var title: String {
        switch self {
        case .immediately: "立即"
        case .oneMinute: "1 分钟"
        case .fiveMinutes: "5 分钟"
        case .fifteenMinutes: "15 分钟"
        }
    }
}

@MainActor
final class AppPreferences: ObservableObject {
    private enum Key {
        static let clipboardDuration = "clipboardDuration"
        static let autoLockDuration = "autoLockDuration"
        static let biometricEnabled = "biometricEnabled"
    }

    private let defaults: UserDefaults

    @Published var clipboardDuration: Int {
        didSet { defaults.set(clipboardDuration, forKey: Key.clipboardDuration) }
    }
    @Published var autoLockDuration: AutoLockDuration {
        didSet { defaults.set(autoLockDuration.rawValue, forKey: Key.autoLockDuration) }
    }
    @Published var biometricEnabled: Bool {
        didSet { defaults.set(biometricEnabled, forKey: Key.biometricEnabled) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let clipboard = defaults.integer(forKey: Key.clipboardDuration)
        self.clipboardDuration = [15, 30, 60].contains(clipboard) ? clipboard : 60
        let lockValue = defaults.object(forKey: Key.autoLockDuration) as? Int ?? 300
        self.autoLockDuration = AutoLockDuration(rawValue: lockValue) ?? .fiveMinutes
        self.biometricEnabled = defaults.bool(forKey: Key.biometricEnabled)
    }
}
