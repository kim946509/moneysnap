import Foundation

enum TodayCanvasLayout {
    static func imageSize(
        for entry: TodaySnapEntry,
        maximumAmount: KrwAmount
    ) -> CGSize {
        guard let artwork = entry.artwork else { return .zero }

        let amountRatio = CGFloat(entry.amount.value) / CGFloat(maximumAmount.value)
        let readableScale = max(CGFloat(0.72), amountRatio.squareRoot())
        let longestSide = CGFloat(150) * readableScale

        if artwork.canvasAspectRatio >= 1 {
            return CGSize(
                width: longestSide.rounded(),
                height: (longestSide / artwork.canvasAspectRatio).rounded()
            )
        }
        return CGSize(
            width: (longestSide * artwork.canvasAspectRatio).rounded(),
            height: longestSide.rounded()
        )
    }
}
