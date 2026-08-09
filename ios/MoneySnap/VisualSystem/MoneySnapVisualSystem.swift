import SwiftUI

enum MoneySnapVisualSystem {
    static let ink = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let navy = Color(red: 0.08, green: 0.11, blue: 0.20)
    static let charcoal = Color(red: 0.12, green: 0.13, blue: 0.16)
    static let secondaryText = Color(red: 0.53, green: 0.52, blue: 0.58)
    static let lightGray = Color(red: 0.79, green: 0.79, blue: 0.82)
}

extension Font {
    static func moneySnap(size: CGFloat, weight: Weight) -> Font {
        .custom("Noto Sans KR", size: size).weight(weight)
    }
}

extension Int64 {
    var wonText: String {
        "₩" + formatted(.number.grouping(.automatic))
    }
}
