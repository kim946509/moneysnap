import CoreGraphics
import Foundation

struct TodayCanvasDriftBody: Equatable, Sendable {
    var id: UUID
    var center: CGPoint
    var velocity: CGVector
    var radius: CGFloat
    var rotation: CGFloat = 0
    var spin: CGFloat = 0.08
}

enum TodayCanvasDrift {
    static let spring: CGFloat = 0.05
    static let wallBounce: CGFloat = -0.9
    static let frameDuration: CGFloat = 1 / 60

    static func step(
        bodies: inout [TodayCanvasDriftBody],
        bounds: CGRect,
        dt: CGFloat,
        time: TimeInterval = 0
    ) {
        let frames = max(1, min(3, Int((max(dt, 0) / frameDuration).rounded(.up))))
        for _ in 0..<frames {
            collide(&bodies)
            move(&bodies, bounds: bounds, time: time)
        }
    }

    static func playBounds(canvasSize: CGSize) -> CGRect {
        CGRect(
            x: 18,
            y: TodayCanvasPlacement.physicsCeilingY,
            width: max(0, canvasSize.width - 36),
            height: max(0, TodayCanvasPlacement.physicsFloorY - TodayCanvasPlacement.physicsCeilingY)
        )
    }

    private static func collide(_ bodies: inout [TodayCanvasDriftBody]) {
        guard bodies.count > 1 else { return }
        for i in 0..<(bodies.count - 1) {
            for j in (i + 1)..<bodies.count {
                var a = bodies[i]
                var b = bodies[j]
                let dx = b.center.x - a.center.x
                let dy = b.center.y - a.center.y
                var distance = hypot(dx, dy)
                let minDist = a.radius + b.radius
                if distance >= minDist { continue }
                if distance < 0.001 {
                    distance = 0.001
                }
                let nx = dx / distance
                let ny = dy / distance
                let overlap = minDist - distance
                a.center.x -= nx * overlap / 2
                a.center.y -= ny * overlap / 2
                b.center.x += nx * overlap / 2
                b.center.y += ny * overlap / 2
                let ax = nx * overlap * spring
                let ay = ny * overlap * spring
                a.velocity.dx -= ax / frameDuration
                a.velocity.dy -= ay / frameDuration
                b.velocity.dx += ax / frameDuration
                b.velocity.dy += ay / frameDuration
                bodies[i] = a
                bodies[j] = b
            }
        }
    }

    private static func move(
        _ bodies: inout [TodayCanvasDriftBody],
        bounds: CGRect,
        time: TimeInterval
    ) {
        let cruise = TodayCanvasPlacement.floatCruiseSpeed
        let cap = TodayCanvasPlacement.floatSpeedLimit
        for index in bodies.indices {
            var body = bodies[index]
            body.center.x += body.velocity.dx * frameDuration
            body.center.y += body.velocity.dy * frameDuration
            body.rotation += body.spin * frameDuration

            let minX = bounds.minX + body.radius
            let maxX = bounds.maxX - body.radius
            let minY = bounds.minY + body.radius
            let maxY = bounds.maxY - body.radius
            if body.center.x > maxX {
                body.center.x = maxX
                body.velocity.dx *= wallBounce
            } else if body.center.x < minX {
                body.center.x = minX
                body.velocity.dx *= wallBounce
            }
            if body.center.y > maxY {
                body.center.y = maxY
                body.velocity.dy *= wallBounce
            } else if body.center.y < minY {
                body.center.y = minY
                body.velocity.dy *= wallBounce
            }

            let speed = hypot(body.velocity.dx, body.velocity.dy)
            if speed < cruise * 0.4 {
                let heading = CGFloat(time * 0.32 + Double(body.id.uuid.0) / 26)
                body.velocity = CGVector(dx: cos(heading) * cruise, dy: sin(heading * 1.13) * cruise)
            } else if speed > cap {
                let scale = cap / speed
                body.velocity = CGVector(dx: body.velocity.dx * scale, dy: body.velocity.dy * scale)
            }
            bodies[index] = body
        }
    }
}
