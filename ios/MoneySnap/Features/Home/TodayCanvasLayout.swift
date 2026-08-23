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
}
