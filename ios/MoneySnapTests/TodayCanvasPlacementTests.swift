import Foundation
import Testing
@testable import MoneySnap

struct TodayCanvasPlacementTests {
    @Test
    func restCentersMatchTheReviewedHomeCanvas() {
        let width: CGFloat = 393

        #expect(TodayCanvasPlacement.restCenter(index: 0, canvasWidth: width) == CGPoint(x: width * 0.357, y: 276))
        #expect(TodayCanvasPlacement.restCenter(index: 1, canvasWidth: width) == CGPoint(x: width * 0.736, y: 303))
        #expect(TodayCanvasPlacement.restCenter(index: 2, canvasWidth: width) == CGPoint(x: width * 0.256, y: 354))
    }

    @Test
    func physicsDropStartsAboveTheRestingCanvas() {
        let id = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        let drop = TodayCanvasPlacement.pose(
            id: id,
            index: 0,
            canvasWidth: 393,
            motion: .physics,
            isNew: true
        )
        let rest = TodayCanvasPlacement.pose(
            id: id,
            index: 0,
            canvasWidth: 393,
            motion: .physics,
            isNew: false
        )

        #expect(drop.center.y < rest.center.y)
        #expect(rest.center == CGPoint(x: 393 * 0.357, y: 276))
    }

    @Test
    func reduceMotionAndVisualHomeKeepRestingCoordinates() {
        let id = UUID()
        let reduced = TodayCanvasPlacement.pose(
            id: id,
            index: 0,
            canvasWidth: 393,
            motion: .staticRest,
            isNew: true
        )

        #expect(reduced.center == CGPoint(x: 393 * 0.357, y: 276))
        #expect(
            TodayCanvasPlacement.motion(
                reduceMotion: true,
                visualScenario: nil
            ) == .staticRest
        )
        #expect(
            TodayCanvasPlacement.motion(
                reduceMotion: false,
                visualScenario: "home"
            ) == .staticRest
        )
        #expect(
            TodayCanvasPlacement.motion(
                reduceMotion: false,
                visualScenario: nil
            ) == .physics
        )
    }
}
