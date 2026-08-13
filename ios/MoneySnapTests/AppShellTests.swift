import Foundation
import Testing
@testable import MoneySnap

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

    @Test
    func visualLaunchUsesLiveWiringOnlyWhenScenarioVariableIsAbsent() {
        #expect(VisualTestSupport.resolve(environment: [:]) == .live)
        #expect(
            VisualTestSupport.resolve(
                environment: ["MONEYSNAP_VISUAL_SCENARIO": "unknown"]
            ) == .invalid("unknown")
        )
        #expect(
            VisualTestSupport.resolve(
                environment: ["MONEYSNAP_VISUAL_SCENARIO": ""]
            ) == .invalid("")
        )
    }

    @Test
    func visualScenarioAllowlistKeepsReviewedOrder() {
        #expect(VisualScenario.allCases == [.home, .my])
    }
}
