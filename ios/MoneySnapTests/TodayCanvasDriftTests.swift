import Foundation
import Testing
@testable import MoneySnap

struct TodayCanvasDriftTests {
    private let bounds = CGRect(x: 18, y: 96, width: 357, height: 320)

    @Test
    func overlappingTokensSeparatePastTheirRadii() {
        var bodies = [
            TodayCanvasDriftBody(
                id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
                center: CGPoint(x: 120, y: 200),
                velocity: CGVector(dx: 0, dy: 0),
                radius: 30
            ),
            TodayCanvasDriftBody(
                id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
                center: CGPoint(x: 130, y: 200),
                velocity: CGVector(dx: 0, dy: 0),
                radius: 30
            )
        ]

        TodayCanvasDrift.step(bodies: &bodies, bounds: bounds, dt: 1 / 60)

        let distance = hypot(
            bodies[1].center.x - bodies[0].center.x,
            bodies[1].center.y - bodies[0].center.y
        )
        #expect(distance >= 60 - 0.5)
    }

    @Test
    func aTokenPastTheRightWallComesBackInAndReverses() {
        var bodies = [
            TodayCanvasDriftBody(
                id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
                center: CGPoint(x: 400, y: 200),
                velocity: CGVector(dx: 40, dy: 0),
                radius: 20
            )
        ]

        TodayCanvasDrift.step(bodies: &bodies, bounds: bounds, dt: 1 / 60)

        let maxX = bounds.maxX - 20
        #expect(bodies[0].center.x <= maxX + 0.01)
        #expect(bodies[0].velocity.dx < 0)
    }

    @Test
    func cruiseDoesNotOverwriteABounceWhileMoving() {
        var bodies = [
            TodayCanvasDriftBody(
                id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
                center: CGPoint(x: 160, y: 200),
                velocity: CGVector(dx: -48, dy: 0),
                radius: 24
            )
        ]

        TodayCanvasDrift.step(bodies: &bodies, bounds: bounds, dt: 1 / 60, time: 4)

        #expect(bodies[0].velocity.dx < 0)
        #expect(abs(bodies[0].velocity.dx) > 30)
    }
}
