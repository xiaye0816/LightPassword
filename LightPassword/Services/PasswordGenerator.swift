import Foundation
import Security

struct PasswordGeneratorOptions: Equatable, Sendable {
    var length = 20
    var includesLowercase = true
    var includesUppercase = true
    var includesDigits = true
    var includesSymbols = true
    var excludesAmbiguous = true
}

enum PasswordGeneratorError: LocalizedError {
    case noCharacterSet
    case invalidLength
    case randomFailure

    var errorDescription: String? {
        switch self {
        case .noCharacterSet: "请至少选择一种字符类型。"
        case .invalidLength: "密码长度必须在 12 到 64 位之间。"
        case .randomFailure: "无法获取安全随机数。"
        }
    }
}

protocol PasswordGenerator {
    func generate(options: PasswordGeneratorOptions) throws -> String
}

struct SecurePasswordGenerator: PasswordGenerator {
    private let lowercase = Array("abcdefghijklmnopqrstuvwxyz")
    private let uppercase = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ")
    private let digits = Array("0123456789")
    private let symbols = Array("!@#$%^&*()-_=+[]{}:,.?")
    private let ambiguous = Set("Il1O0o|".map { $0 })

    func generate(options: PasswordGeneratorOptions) throws -> String {
        guard (12...64).contains(options.length) else { throw PasswordGeneratorError.invalidLength }
        var groups: [[Character]] = []
        if options.includesLowercase { groups.append(filtered(lowercase, options: options)) }
        if options.includesUppercase { groups.append(filtered(uppercase, options: options)) }
        if options.includesDigits { groups.append(filtered(digits, options: options)) }
        if options.includesSymbols { groups.append(filtered(symbols, options: options)) }
        groups = groups.filter { !$0.isEmpty }
        guard !groups.isEmpty else { throw PasswordGeneratorError.noCharacterSet }

        let all = groups.flatMap { $0 }
        var result = try groups.map { group in group[try secureIndex(upperBound: group.count)] }
        while result.count < options.length {
            result.append(all[try secureIndex(upperBound: all.count)])
        }
        for index in stride(from: result.count - 1, through: 1, by: -1) {
            let swapIndex = try secureIndex(upperBound: index + 1)
            result.swapAt(index, swapIndex)
        }
        return String(result)
    }

    private func filtered(_ input: [Character], options: PasswordGeneratorOptions) -> [Character] {
        options.excludesAmbiguous ? input.filter { !ambiguous.contains($0) } : input
    }

    private func secureIndex(upperBound: Int) throws -> Int {
        precondition(upperBound > 0 && upperBound <= 256)
        let limit = 256 - (256 % upperBound)
        while true {
            var byte: UInt8 = 0
            let status = withUnsafeMutableBytes(of: &byte) { buffer in
                SecRandomCopyBytes(kSecRandomDefault, 1, buffer.baseAddress!)
            }
            guard status == errSecSuccess else { throw PasswordGeneratorError.randomFailure }
            if Int(byte) < limit { return Int(byte) % upperBound }
        }
    }
}
