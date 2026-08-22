import Foundation

enum TodayCanvasMotion: Equatable, Sendable {
    case physics
    case staticRest
}

struct TodayCanvasPose: Equatable, Sendable {
    var center: CGPoint
    var rotation: CGFloat
}

enum TodayCanvasPlacement {
    static let floorY: CGFloat = 400
    static let ceilingY: CGFloat = 92
    static let dropY: CGFloat = 108

    static func motion(reduceMotion: Bool, visualScenario: String?) -> TodayCanvasMotion {
        if reduceMotion { return .staticRest }
        if visualScenario != nil { return .staticRest }
        return .physics
    }

    static func restCenter(index: Int, canvasWidth: CGFloat) -> CGPoint {
        switch index {
        case 0: CGPoint(x: canvasWidth * 0.357, y: 276)
        case 1: CGPoint(x: canvasWidth * 0.736, y: 303)
        default: CGPoint(x: canvasWidth * 0.256, y: 354)
        }
    }

    static func cardSize(index: Int) -> CGSize {
        switch index {
        case 0: CGSize(width: 189, height: 170)
        case 1: CGSize(width: 116, height: 191)
        default: CGSize(width: 112, height: 50)
        }
    }

    static func pose(
        id: UUID,
        index: Int,
        canvasWidth: CGFloat,
        motion: TodayCanvasMotion,
        isNew: Bool
    ) -> TodayCanvasPose {
        let rest = restCenter(index: index, canvasWidth: canvasWidth)
        guard motion == .physics, isNew else {
            return TodayCanvasPose(center: rest, rotation: 0)
        }
        let jitter = CGFloat(id.uuid.0 % 37) - 18
        return TodayCanvasPose(
            center: CGPoint(x: rest.x + jitter, y: dropY),
            rotation: 0
        )
    }
}
