import SwiftUI
import UIKit

struct CanvasSnapToken: View {
    let entry: TodaySnapEntry
    let imageSize: CGSize

    var body: some View {
        ZStack(alignment: .bottom) {
            snapImage
            if entry.revealsAmount {
                PriceTicket(entry: entry)
                    .scaleEffect(min(1, imageSize.width / 112), anchor: .bottom)
                    .offset(y: 10)
            }
        }
        .frame(width: imageSize.width, height: imageSize.height)
    }

    @ViewBuilder
    private var snapImage: some View {
        if let artwork = entry.artwork {
            Image(artwork.rawValue)
                .resizable()
                .scaledToFill()
                .frame(width: imageSize.width, height: imageSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if let jpeg = entry.previewJPEG, let image = UIImage(data: jpeg) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: imageSize.width, height: imageSize.height)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .accessibilityIdentifier("home.photo.featured.\(entry.id.uuidString.lowercased())")
        } else {
            SnapCategoryPlaceholder(entry: entry, surface: .featured)
                .frame(width: imageSize.width, height: imageSize.height)
        }
    }
}

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
            } else if let jpeg = entry.previewJPEG, let image = UIImage(data: jpeg) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize.width, height: imageSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: layout == .landscape ? 19 : 14))
                    .rotationEffect(.degrees(rotation))
                    .accessibilityIdentifier("home.photo.featured.\(entry.id.uuidString.lowercased())")
            } else {
                SnapCategoryPlaceholder(entry: entry, surface: .featured)
                    .frame(width: imageSize.width, height: imageSize.height)
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
                    .accessibilityIdentifier("home.recent.\(entry.id.uuidString.lowercased())")
            } else if let jpeg = entry.previewJPEG, let image = UIImage(data: jpeg) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .accessibilityIdentifier("home.photo.recent.\(entry.id.uuidString.lowercased())")
            } else {
                SnapCategoryPlaceholder(entry: entry, surface: .recent)
                    .frame(width: 34, height: 34)
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

struct SnapCategoryPlaceholder: View {
    enum Surface: String {
        case featured
        case recent
        case detail
    }

    let entry: TodaySnapEntry
    let surface: Surface

    var body: some View {
        Image(systemName: entry.category.placeholderSymbol)
            .font(.system(size: symbolSize, weight: .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Exact category palette remains design-gated; use an approved neutral token meanwhile.
            .background(MoneySnapVisualSystem.profileNeutralFill, in: RoundedRectangle(cornerRadius: cornerRadius))
            .foregroundStyle(MoneySnapVisualSystem.charcoal)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(entry.category.title) 사진 없음")
            .accessibilityIdentifier("home.placeholder.\(surface.rawValue).\(entry.id.uuidString.lowercased())")
    }

    private var symbolSize: CGFloat {
        switch surface {
        case .featured: 34
        case .recent: 15
        case .detail: 72
        }
    }

    private var cornerRadius: CGFloat {
        switch surface {
        case .featured: 20
        case .recent: 7
        case .detail: 22
        }
    }
}

extension SnapCategory {
    var placeholderSymbol: String {
        switch self {
        case .food: "fork.knife"
        case .cafe: "cup.and.saucer.fill"
        case .transportation: "bus.fill"
        case .shopping: "bag.fill"
        case .living: "house.fill"
        case .culture: "theatermasks.fill"
        case .health: "cross.case.fill"
        case .other: "circle.grid.2x2.fill"
        }
    }

}
