import SwiftUI

struct TodaySnapView: View {
    @State private var viewModel: TodaySnapViewModel
    let onRecord: () -> Void
    let onMenu: () -> Void

    init(
        client: any SnapJournalClient,
        onRecord: @escaping () -> Void,
        onMenu: @escaping () -> Void
    ) {
        _viewModel = State(initialValue: TodaySnapViewModel(client: client))
        self.onRecord = onRecord
        self.onMenu = onMenu
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.white

                switch viewModel.state {
                case .loading:
                    ProgressView()
                case let .content(summary):
                    TodaySnapContent(
                        summary: summary,
                        onRecord: onRecord,
                        onMenu: onMenu
                    )
                case .failure:
                    ContentUnavailableView(
                        "오늘 기록을 불러오지 못했어요",
                        systemImage: "exclamationmark.arrow.triangle.2.circlepath"
                    )
                }
            }
            .frame(width: 393, height: 852)
            .scaleEffect(
                min(proxy.size.width / 393, proxy.size.height / 852),
                anchor: .topLeading
            )
        }
        .ignoresSafeArea()
        .task { await viewModel.load() }
    }
}

private struct TodaySnapContent: View {
    let summary: TodaySnapSummary
    let onRecord: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            header
            featuredCards
            recordButton
            pageIndicator
            totalSection
            recentSection
        }
        .frame(width: 393, height: 852)
    }

    private var header: some View {
        Group {
            VStack(alignment: .leading, spacing: 1) {
                Text("Today Snap")
                    .font(.moneySnap(size: 24, weight: .bold))
                    .foregroundStyle(MoneySnapColor.ink)
                Text(summary.dateLabel)
                    .font(.moneySnap(size: 14, weight: .regular))
                    .foregroundStyle(MoneySnapColor.secondary)
            }
            .position(x: 91, y: 96)

            Button(action: onMenu) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(MoneySnapColor.navy, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 9)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("메뉴")
            .position(x: 353, y: 93)
        }
    }

    private var featuredCards: some View {
        Group {
            if let entry = summary.featuredEntries[safe: 0] {
                FeaturedSnapCard(entry: entry, imageSize: CGSize(width: 150, height: 109))
                    .rotationEffect(.degrees(7))
                    .position(x: 146, y: 321)
            }
            if let entry = summary.featuredEntries[safe: 1] {
                FeaturedSnapCard(entry: entry, imageSize: CGSize(width: 82, height: 108))
                    .rotationEffect(.degrees(-7))
                    .position(x: 299, y: 354)
            }
            if let entry = summary.featuredEntries[safe: 2] {
                PriceTicket(entry: entry)
                    .rotationEffect(.degrees(-3))
                    .position(x: 100, y: 414)
            }
        }
    }

    private var recordButton: some View {
        Button(action: onRecord) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.18), in: Circle())
                Text("기록하기")
                    .font(.moneySnap(size: 21, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(width: 165, height: 64)
            .background(MoneySnapColor.charcoal, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 14, y: 10)
        }
        .buttonStyle(.plain)
        .position(x: 196.5, y: 495)
    }

    private var pageIndicator: some View {
        HStack(spacing: 4) {
            Circle().fill(MoneySnapColor.ink).frame(width: 5, height: 5)
            Circle().fill(MoneySnapColor.lightGray).frame(width: 5, height: 5)
        }
        .frame(width: 45, height: 20)
        .background(.white, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .position(x: 196.5, y: 562)
    }

    private var totalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("오늘 총 소비")
                .font(.moneySnap(size: 17, weight: .regular))
                .foregroundStyle(MoneySnapColor.secondary)
            Text(summary.totalAmount.wonText)
                .font(.moneySnap(size: 64, weight: .black))
                .tracking(-4.5)
                .foregroundStyle(.black)
                .frame(height: 78, alignment: .topLeading)
        }
        .position(x: 156, y: 632)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("오늘 소비")
                .font(.moneySnap(size: 18, weight: .bold))
                .foregroundStyle(MoneySnapColor.ink)
            HStack(spacing: 52) {
                ForEach(summary.recentEntries) { entry in
                    RecentSnapRow(entry: entry)
                }
            }
        }
        .position(x: 171, y: 718)
    }
}

private struct FeaturedSnapCard: View {
    let entry: TodaySnapEntry
    let imageSize: CGSize

    var body: some View {
        VStack(spacing: -6) {
            if let imageName = entry.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize.width, height: imageSize.height)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            PriceTicket(entry: entry)
        }
    }
}

private struct PriceTicket: View {
    let entry: TodaySnapEntry

    var body: some View {
        VStack(spacing: -2) {
            Text(entry.amount.wonText)
                .font(.moneySnap(size: 20, weight: .black))
                .tracking(-1.3)
            Text(entry.category.title)
                .font(.moneySnap(size: 8, weight: .regular))
                .foregroundStyle(MoneySnapColor.secondary)
        }
        .frame(width: 108, height: 52)
        .background(.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 14, y: 10)
    }
}

private struct RecentSnapRow: View {
    let entry: TodaySnapEntry

    var body: some View {
        HStack(spacing: 8) {
            if let imageName = entry.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.category.title)
                    .font(.moneySnap(size: 9, weight: .regular))
                    .foregroundStyle(MoneySnapColor.secondary)
                Text(entry.amount.wonText)
                    .font(.moneySnap(size: 12, weight: .bold))
                    .foregroundStyle(.black)
            }
        }
        .frame(width: 128, alignment: .leading)
    }
}

private enum MoneySnapColor {
    static let ink = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let navy = Color(red: 0.08, green: 0.11, blue: 0.20)
    static let charcoal = Color(red: 0.12, green: 0.13, blue: 0.16)
    static let secondary = Color(red: 0.53, green: 0.52, blue: 0.58)
    static let lightGray = Color(red: 0.79, green: 0.79, blue: 0.82)
}

private extension Font {
    static func moneySnap(size: CGFloat, weight: Weight) -> Font {
        .custom("Noto Sans KR", size: size).weight(weight)
    }
}

private extension Int64 {
    var wonText: String {
        "₩" + formatted(.number.grouping(.automatic))
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    TodaySnapView(
        client: InMemorySnapJournalClient.fixture,
        onRecord: {},
        onMenu: {}
    )
}
