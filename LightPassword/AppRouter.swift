import Combine
import Foundation

enum AppTab: Hashable {
    case passwords
    case trash
    case settings
}

struct PendingAddPasswordRequest: Identifiable, Equatable {
    let id = UUID()
}

@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()
    static let addPasswordShortcutType = "com.shaoguoqing.lightpassword.add-password"

    @Published var selectedTab: AppTab = .passwords
    @Published private(set) var pendingAddPasswordRequest: PendingAddPasswordRequest?

    init() {}

    @discardableResult
    func enqueueShortcut(type: String) -> Bool {
        guard type == Self.addPasswordShortcutType else { return false }
        selectedTab = .passwords
        if pendingAddPasswordRequest == nil {
            pendingAddPasswordRequest = PendingAddPasswordRequest()
        }
        return true
    }

    func consumeAddPasswordRequest(id: UUID) {
        guard pendingAddPasswordRequest?.id == id else { return }
        pendingAddPasswordRequest = nil
    }
}
