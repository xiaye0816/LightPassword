import Testing
@testable import LightPassword

@MainActor
struct AppRouterTests {
    @Test func addPasswordShortcutQueuesOnceAndSelectsPasswordTab() throws {
        let router = AppRouter()
        router.selectedTab = .settings

        #expect(!router.enqueueShortcut(type: "unsupported"))
        #expect(router.pendingAddPasswordRequest == nil)
        #expect(router.enqueueShortcut(type: AppRouter.addPasswordShortcutType))
        #expect(router.selectedTab == .passwords)

        let firstRequest = try #require(router.pendingAddPasswordRequest)
        #expect(router.enqueueShortcut(type: AppRouter.addPasswordShortcutType))
        #expect(router.pendingAddPasswordRequest?.id == firstRequest.id)

        router.consumeAddPasswordRequest(id: firstRequest.id)
        #expect(router.pendingAddPasswordRequest == nil)
    }
}
