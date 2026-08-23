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
    func sidebarListsPrimaryDestinationsWithoutTheAddTab() {
        #expect(AppTab.allCases.filter { $0 != .add } == [.home, .group, .archive, .profile])
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
        #expect(VisualScenario.allCases == [.home, .my, .recordCategory, .recordAmount])
        #expect(
            VisualTestSupport.resolve(
                environment: ["MONEYSNAP_VISUAL_SCENARIO": "record-category"]
            ) == .scenario(.recordCategory)
        )
        #expect(
            VisualTestSupport.resolve(
                environment: ["MONEYSNAP_VISUAL_SCENARIO": "record-amount"]
            ) == .scenario(.recordAmount)
        )
    }

    @Test
    func recordAmountVisualScenarioSeedsTheReviewedDraft() throws {
        let model = try #require(
            VisualTestSupport.initialCaptureModel(
                for: .recordAmount,
                client: VisualTestSupport.snapJournalClient
            )
        )

        #expect(model.phase == .amount)
        #expect(model.selectedCategory == .food)
        #expect(model.amountText == "₩18,900")
    }

    @Test
    func recordCategoryVisualScenarioSeedsTheReviewedSelection() throws {
        let model = try #require(
            VisualTestSupport.initialCaptureModel(
                for: .recordCategory,
                client: VisualTestSupport.snapJournalClient
            )
        )

        #expect(model.phase == .category)
        #expect(model.selectedCategory == .food)
    }

    @Test
    func unknownFeatureScenarioFailsClosed() {
        #expect(VisualTestSupport.resolveFeature(environment: [:]) == .absent)
        #expect(
            VisualTestSupport.resolveFeature(
                environment: ["MONEYSNAP_FEATURE_SCENARIO": "record"]
            ) == .record
        )
        #expect(
            VisualTestSupport.resolveFeature(
                environment: ["MONEYSNAP_FEATURE_SCENARIO": "record-retry"]
            ) == .recordRetry
        )
        #expect(
            VisualTestSupport.resolveFeature(
                environment: ["MONEYSNAP_FEATURE_SCENARIO": "unknown"]
            ) == .invalid("unknown")
        )
    }
}
