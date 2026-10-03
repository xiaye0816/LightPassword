import SwiftUI

struct PasswordGeneratorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let onUse: (String) -> Void

    @State private var options = PasswordGeneratorOptions()
    @State private var generated = ""
    @State private var errorMessage: String?
    private let generator = SecurePasswordGenerator()

    var body: some View {
        NavigationStack {
            Form {
                Section("生成结果") {
                    Text(generated)
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("生成的密码")
                    HStack {
                        Button("重新生成", systemImage: "arrow.clockwise", action: generate)
                        Spacer()
                        Button("复制", systemImage: "doc.on.doc") {
                            model.copyGeneratedPassword(generated)
                        }
                        .disabled(generated.isEmpty)
                    }
                }

                Section("长度：\(options.length) 位") {
                    Slider(
                        value: Binding(
                            get: { Double(options.length) },
                            set: { options.length = Int($0); generate() }
                        ),
                        in: 12...64,
                        step: 1
                    )
                }

                Section("字符") {
                    Toggle("小写字母", isOn: optionBinding(\.includesLowercase))
                    Toggle("大写字母", isOn: optionBinding(\.includesUppercase))
                    Toggle("数字", isOn: optionBinding(\.includesDigits))
                    Toggle("符号", isOn: optionBinding(\.includesSymbols))
                    Toggle("排除易混淆字符", isOn: optionBinding(\.excludesAmbiguous))
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("密码生成器")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("使用") { onUse(generated) }
                        .disabled(generated.isEmpty)
                }
            }
            .onAppear(perform: generate)
        }
    }

    private func optionBinding(_ keyPath: WritableKeyPath<PasswordGeneratorOptions, Bool>) -> Binding<Bool> {
        Binding {
            options[keyPath: keyPath]
        } set: { newValue in
            options[keyPath: keyPath] = newValue
            generate()
        }
    }

    private func generate() {
        do {
            generated = try generator.generate(options: options)
            errorMessage = nil
        } catch {
            generated = ""
            errorMessage = error.localizedDescription
        }
    }
}
