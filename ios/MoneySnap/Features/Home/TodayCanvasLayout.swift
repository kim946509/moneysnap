import Foundation

enum TodayCanvasLayout {
    static let placeholderLongestSide: CGFloat = 108

    static func imageSize(
        for entry: TodaySnapEntry,
        maximumAmount: KrwAmount
    ) -> CGSize {
        let amountRatio = CGFloat(entry.amount.value) / CGFloat(maximumAmount.value)
        let readableScale = max(CGFloat(0.62), amountRatio.squareRoot())
        let aspectRatio = entry.artwork?.canvasAspectRatio ?? 1
        let longestSide = (entry.artwork?.canvasLongestSide ?? placeholderLongestSide) * readableScale

        if aspectRatio >= 1 {
            return CGSize(
                width: longestSide.rounded(),
                height: (longestSide / aspectRatio).rounded()
            )
        }
        return CGSize(
            width: (longestSide * aspectRatio).rounded(),
            height: longestSide.rounded()
        )
    }

    static func physicsCardSize(
        for entry: TodaySnapEntry,
        maximumAmount: KrwAmount
    ) -> CGSize {
        let ratio = CGFloat(entry.amount.value) / CGFloat(maximumAmount.value)
        let scale = max(CGFloat(0.78), ratio.squareRoot())
        let baseSize = switch entry.artwork {
        case .some(.food): CGSize(width: 154, height: 112)
        case .some(.cafe): CGSize(width: 116, height: 146)
        case nil: CGSize(width: 132, height: 96)
        }

        return CGSize(
            width: (baseSize.width * scale).rounded(),
            height: (baseSize.height * scale).rounded()
        )
    }
}

enum TodayCanvasPhysics {
    static let defaultGravity = CGVector(dx: 0, dy: -5.8)

    static func gravity(deviceX: Double, deviceY: Double) -> CGVector {
        CGVector(
            dx: max(-8, min(8, deviceX * 8)),
            dy: max(-8, min(8, deviceY * 8))
        )
    }
}
