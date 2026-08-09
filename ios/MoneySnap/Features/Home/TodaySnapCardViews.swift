import SwiftUI

struct FeaturedSnapCard: View {
    let entry: TodaySnapEntry
    let imageSize: CGSize

    var body: some View {
        VStack(spacing: -6) {
            if let artwork = entry.artwork {
                Image(artwork.rawValue)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize.width, height: imageSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            PriceTicket(entry: entry)
        }
    }
}

struct PriceTicket: View {
    let entry: TodaySnapEntry

    var body: some View {
        VStack(spacing: -2) {
            Text(entry.amount.value.wonText)
                .font(.moneySnap(size: 20, weight: .black))
                .tracking(-1.3)
            Text(entry.category.title)
                .font(.moneySnap(size: 8, weight: .regular))
                .foregroundStyle(MoneySnapVisualSystem.secondaryText)
        }
        .frame(width: 108, height: 52)
        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 10)
    }
}

struct RecentSnapRow: View {
    let entry: TodaySnapEntry

    var body: some View {
        HStack(spacing: 8) {
            if let artwork = entry.artwork {
                Image(artwork.rawValue)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.category.title)
                    .font(.moneySnap(size: 9, weight: .regular))
                    .foregroundStyle(MoneySnapVisualSystem.secondaryText)
                Text(entry.amount.value.wonText)
                    .font(.moneySnap(size: 12, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .frame(width: 128, alignment: .leading)
    }
}
