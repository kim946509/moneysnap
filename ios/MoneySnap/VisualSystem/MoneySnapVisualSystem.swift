import SwiftUI

enum MoneySnapVisualSystem {
    static let ink = Color(red: 17.0 / 255, green: 17.0 / 255, blue: 22.0 / 255)
    static let navy = Color(red: 17.0 / 255, green: 26.0 / 255, blue: 51.0 / 255)
    static let charcoal = Color(red: 35.0 / 255, green: 37.0 / 255, blue: 45.0 / 255)
    static let secondaryText = Color(red: 138.0 / 255, green: 135.0 / 255, blue: 146.0 / 255)
    static let priceText = Color(red: 31.0 / 255, green: 31.0 / 255, blue: 36.0 / 255)
    static let chipSecondaryText = Color(red: 89.0 / 255, green: 89.0 / 255, blue: 99.0 / 255)
    static let recentText = Color(red: 20.0 / 255, green: 20.0 / 255, blue: 26.0 / 255)
    static let recentSecondaryText = Color(red: 135.0 / 255, green: 135.0 / 255, blue: 148.0 / 255)
    static let lightGray = Color(red: 0.79, green: 0.79, blue: 0.82)
    static let profileSecondaryText = Color(red: 138.0 / 255, green: 141.0 / 255, blue: 153.0 / 255)
    static let profileBadgeText = Color(red: 46.0 / 255, green: 48.0 / 255, blue: 56.0 / 255)
    static let profileNeutralFill = Color(red: 240.0 / 255, green: 241.0 / 255, blue: 244.0 / 255)
    static let profileBorder = Color(red: 239.0 / 255, green: 239.0 / 255, blue: 242.0 / 255)
    static let profileAvatar = Color(red: 1, green: 211.0 / 255, blue: 220.0 / 255)
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
