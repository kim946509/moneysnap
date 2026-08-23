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
    static let recordButtonCenterY: CGFloat = 448
    static let recordButtonHeight: CGFloat = 51
    static let recordButtonWidth: CGFloat = 132
    static let physicsCeilingY: CGFloat = 96
    static let physicsFloorY: CGFloat = 416
    static let floatSpeedLimit: CGFloat = 58
    static let floatCruiseSpeed: CGFloat = 24

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
        pose(
            id: id,
            index: index,
            count: max(index + 1, 1),
            canvasWidth: canvasWidth,
            size: cardSize(index: index),
            motion: motion,
            isNew: isNew
        )
    }

    static func pose(
        id: UUID,
        index: Int,
        count: Int,
        canvasWidth: CGFloat,
        size: CGSize,
        motion: TodayCanvasMotion,
        isNew: Bool
    ) -> TodayCanvasPose {
        if motion != .physics {
            return TodayCanvasPose(center: restCenter(index: index, canvasWidth: canvasWidth), rotation: 0)
        }
        if isNew {
            let rest = packedCenter(index: index, count: count, canvasWidth: canvasWidth, size: size)
            let jitter = CGFloat(id.uuid.0 % 21) - 10
            return TodayCanvasPose(
                center: CGPoint(x: min(max(40, rest.x + jitter), canvasWidth - 40), y: rest.y),
                rotation: 0
            )
        }
        return TodayCanvasPose(
            center: packedCenter(index: index, count: count, canvasWidth: canvasWidth, size: size),
            rotation: 0
        )
    }

    static func collisionRadius(size: CGSize) -> CGFloat {
        max(size.width, size.height) / 2
    }

    static func dropCenterY(size: CGSize) -> CGFloat {
        physicsCeilingY + collisionRadius(size: size) + 10
    }

    static func physicsSize(
        for entry: TodaySnapEntry,
        maximumAmount: KrwAmount,
        count: Int
    ) -> CGSize {
        if !entry.revealsAmount {
            return CGSize(width: 79, height: 79)
        }
        let base = TodayCanvasLayout.imageSize(for: entry, maximumAmount: maximumAmount)
        let crowding = min(1, 3.2 / CGFloat(max(count, 1)))
        let scale = max(0.46, 0.57 + 0.53 * crowding)
        let width = min(97, max(44, (base.width * scale).rounded()))
        let height = min(97, max(44, (base.height * scale).rounded()))
        return CGSize(width: width, height: height)
    }

    static func packedCenter(
        index: Int,
        count: Int,
        canvasWidth: CGFloat,
        size: CGSize
    ) -> CGPoint {
        let columns = min(3, max(count, 1))
        let column = index % columns
        let row = index / columns
        let playHeight = physicsFloorY - physicsCeilingY
        let xSpacing = canvasWidth / CGFloat(columns + 1)
        let ySpacing = min(size.height + 18, playHeight / CGFloat(max((count + columns - 1) / columns, 1) + 1))
        let x = xSpacing * CGFloat(column + 1)
        let y = physicsCeilingY + 36 + size.height / 2 + CGFloat(row) * ySpacing
        let maxCenterY = physicsFloorY - size.height / 2 - 4
        return CGPoint(x: x, y: min(y, maxCenterY))
    }
}
