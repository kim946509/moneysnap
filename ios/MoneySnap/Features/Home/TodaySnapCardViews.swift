import SwiftUI

struct FeaturedSnapCard: View {
    enum Layout: Equatable {
        case landscape
        case portrait
    }

    let entry: TodaySnapEntry
    let imageSize: CGSize
    let layout: Layout

    var body: some View {
        switch layout {
        case .landscape:
            ZStack {
                snapImage(rotation: 7.46)
                    .offset(x: 6.8, y: -31.7)
                PriceTicket(entry: entry)
                    .rotationEffect(.degrees(7))
                    .offset(x: 24.1, y: 33.2)
            }
            .frame(width: 189, height: 170)
        case .portrait:
            ZStack {
                snapImage(rotation: -7.46)
                    .offset(x: 0.2, y: -29.2)
                PriceTicket(entry: entry)
                    .rotationEffect(.degrees(-8))
                    .offset(x: 14, y: 42.5)
            }
            .frame(width: 116, height: 191)
        }
    }

    private func snapImage(rotation: Double) -> some View {
        Group {
            if let artwork = entry.artwork {
                Image(artwork.rawValue)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize.width, height: imageSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: layout == .landscape ? 19 : 14))
                    .rotationEffect(.degrees(rotation))
            }
        }
    }
}

struct PriceTicket: View {
    let entry: TodaySnapEntry

    var body: some View {
        VStack(spacing: 0) {
            Text(entry.amount.value.wonText)
                .font(.moneySnap(size: 17, weight: .bold))
                .foregroundStyle(MoneySnapVisualSystem.priceText)
                .frame(height: 20)
            Text(entry.category.title)
                .font(.moneySnap(size: 9, weight: .medium))
                .foregroundStyle(MoneySnapVisualSystem.chipSecondaryText)
                .frame(height: 12)
        }
        .frame(width: 112, height: 50)
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(.ultraThinMaterial)
                .overlay(RoundedRectangle(cornerRadius: 15).fill(.white.opacity(0.68)))
        }
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(.white.opacity(0.58)))
        .shadow(color: .black.opacity(0.14), radius: 9, y: 8)
    }
}

struct RecentSnapRow: View {
    let entry: TodaySnapEntry

    var body: some View {
        HStack(spacing: 10) {
            if let artwork = entry.artwork {
                Image(artwork.rawValue)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.category.title)
                    .font(.moneySnap(size: 10, weight: .regular))
                    .foregroundStyle(MoneySnapVisualSystem.recentSecondaryText)
                Text(entry.amount.value.wonText)
                    .font(.moneySnap(size: 12, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.recentText)
            }
            .frame(width: 104, alignment: .leading)
        }
        .frame(width: 150, height: 46)
    }
}
