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
        static let generatorLength = "generatorLength"
        static let generatorLowercase = "generatorLowercase"
        static let generatorUppercase = "generatorUppercase"
        static let generatorDigits = "generatorDigits"
        static let generatorSymbols = "generatorSymbols"
        static let generatorExcludesAmbiguous = "generatorExcludesAmbiguous"
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

    var generatorOptions: PasswordGeneratorOptions {
        get {
            let storedLength = defaults.object(forKey: Key.generatorLength) as? Int
            return PasswordGeneratorOptions(
                length: storedLength.flatMap { (12...64).contains($0) ? $0 : nil } ?? 16,
                includesLowercase: storedBool(forKey: Key.generatorLowercase, defaultValue: true),
                includesUppercase: storedBool(forKey: Key.generatorUppercase, defaultValue: true),
                includesDigits: storedBool(forKey: Key.generatorDigits, defaultValue: true),
                includesSymbols: storedBool(forKey: Key.generatorSymbols, defaultValue: false),
                excludesAmbiguous: storedBool(forKey: Key.generatorExcludesAmbiguous, defaultValue: true)
            )
        }
        set {
            defaults.set(newValue.length, forKey: Key.generatorLength)
            defaults.set(newValue.includesLowercase, forKey: Key.generatorLowercase)
            defaults.set(newValue.includesUppercase, forKey: Key.generatorUppercase)
            defaults.set(newValue.includesDigits, forKey: Key.generatorDigits)
            defaults.set(newValue.includesSymbols, forKey: Key.generatorSymbols)
            defaults.set(newValue.excludesAmbiguous, forKey: Key.generatorExcludesAmbiguous)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let clipboard = defaults.integer(forKey: Key.clipboardDuration)
        self.clipboardDuration = [15, 30, 60].contains(clipboard) ? clipboard : 60
        let lockValue = defaults.object(forKey: Key.autoLockDuration) as? Int ?? 300
        self.autoLockDuration = AutoLockDuration(rawValue: lockValue) ?? .fiveMinutes
        self.biometricEnabled = defaults.bool(forKey: Key.biometricEnabled)
    }

    private func storedBool(forKey key: String, defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }
}
