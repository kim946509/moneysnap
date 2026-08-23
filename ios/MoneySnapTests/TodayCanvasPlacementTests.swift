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
    func physicsPlayAreaStaysAboveTheRecordButton() {
        let buttonTop = TodayCanvasPlacement.recordButtonCenterY - TodayCanvasPlacement.recordButtonHeight / 2

        #expect(TodayCanvasPlacement.physicsFloorY < buttonTop)
        #expect(TodayCanvasPlacement.physicsFloorY > 300)
        #expect(TodayCanvasPlacement.dropY > TodayCanvasPlacement.physicsCeilingY)
    }

    @Test
    func droppedBodiesStartFullyBelowTheCeiling() {
        for size in [CGSize(width: 48, height: 48), CGSize(width: 120, height: 120)] {
            let radius = TodayCanvasPlacement.collisionRadius(size: size)
            let y = TodayCanvasPlacement.dropCenterY(size: size)
            #expect(y - radius > TodayCanvasPlacement.physicsCeilingY)
            #expect(y + radius < TodayCanvasPlacement.physicsFloorY)
        }
    }

    @Test
    func livePhysicsSizesShrinkSoManySnapsCanShareTheCanvas() throws {
        let large = TodaySnapEntry(
            id: UUID(),
            category: .food,
            amount: try KrwAmount(18_900)
        )
        let small = TodaySnapEntry(
            id: UUID(),
            category: .cafe,
            amount: try KrwAmount(2_800)
        )
        let few = TodayCanvasPlacement.physicsSize(
            for: large,
            maximumAmount: large.amount,
            count: 2
        )
        let many = TodayCanvasPlacement.physicsSize(
            for: large,
            maximumAmount: large.amount,
            count: 6
        )
        let cheaper = TodayCanvasPlacement.physicsSize(
            for: small,
            maximumAmount: large.amount,
            count: 2
        )

        #expect(few.width <= 120)
        #expect(many.width < few.width)
        #expect(cheaper.width < few.width)
        #expect(many.width >= 48)
    }

    @Test
    func packedCentersStayInsideThePhysicsPlayArea() {
        let size = CGSize(width: 88, height: 88)
        for index in 0..<6 {
            let center = TodayCanvasPlacement.packedCenter(
                index: index,
                count: 6,
                canvasWidth: 393,
                size: size
            )
            #expect(center.y > TodayCanvasPlacement.physicsCeilingY)
            #expect(center.y + size.height / 2 <= TodayCanvasPlacement.physicsFloorY)
            #expect(center.x > 20)
            #expect(center.x < 373)
        }
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
        #expect(drop.center.y == TodayCanvasPlacement.dropCenterY(size: TodayCanvasPlacement.cardSize(index: 0)))
        #expect(rest.center.y < TodayCanvasPlacement.physicsFloorY)
        #expect(rest.center.y > TodayCanvasPlacement.physicsCeilingY)
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
