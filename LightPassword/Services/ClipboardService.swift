import UIKit

@MainActor
protocol ClipboardService {
    func copy(_ value: String, expiresAfter seconds: TimeInterval)
}

@MainActor
final class SystemClipboardService: ClipboardService {
    func copy(_ value: String, expiresAfter seconds: TimeInterval) {
        UIPasteboard.general.setObjects(
            [value as NSString],
            localOnly: true,
            expirationDate: Date().addingTimeInterval(seconds)
        )
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
