import Foundation
import Testing
import MoneySnap

@MainActor
struct AppShellTests {
    @Test
    func initialTabValueIsHome() {
        #expect(AppTab.initial == .home)
    }

    @Test
    func tabsKeepIndependentNavigationHistory() {
        let tabRouter = TabRouter()
        let snapID = UUID(uuidString: "4A97DF9D-CB7C-4D2B-93C7-904C1B759C95")!

        tabRouter.router(for: .home).navigate(to: .snapDetail(id: snapID))

        #expect(tabRouter.router(for: .home).path == [.snapDetail(id: snapID)])
        #expect(tabRouter.router(for: .group).path.isEmpty)
    }
}
