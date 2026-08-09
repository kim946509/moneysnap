import SwiftUI

struct TodaySnapView: View {
    @State private var viewModel: TodaySnapViewModel

    init(client: any SnapJournalClient) {
        _viewModel = State(initialValue: TodaySnapViewModel(client: client))
    }

    var body: some View {
        ZStack {
            Color.white

            switch viewModel.state {
            case .loading:
                ProgressView()
            case let .content(summary):
                TodaySnapContent(summary: summary)
            case .failure:
                ContentUnavailableView(
                    "오늘 기록을 불러오지 못했어요",
                    systemImage: "exclamationmark.arrow.triangle.2.circlepath"
                )
            }
        }
        .task { await viewModel.load() }
    }
}

private struct TodaySnapContent: View {
    let summary: TodaySnapSummary

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                header(availableWidth: proxy.size.width)
                featuredCards(availableWidth: proxy.size.width)
                recordButtonAppearance(availableWidth: proxy.size.width)
                pageIndicator(availableWidth: proxy.size.width)
                totalSection
                recentSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func header(availableWidth: CGFloat) -> some View {
        Group {
            VStack(alignment: .leading, spacing: -2) {
                Text("Today Snap")
                    .font(.moneySnap(size: 22, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                Text(summary.day.displayLabel)
                    .font(.moneySnap(size: 13, weight: .medium))
                    .foregroundStyle(MoneySnapVisualSystem.secondaryText)
            }
            .offset(x: 28, y: 7)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(MoneySnapVisualSystem.navy, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 12, y: 9)
                .accessibilityHidden(true)
                .position(x: availableWidth - 40, y: 34)
        }
    }

    private func featuredCards(availableWidth: CGFloat) -> some View {
        let maximumAmount = summary.featuredEntries.map(\.amount).max()

        return Group {
            if let entry = summary.featuredEntries[safe: 0], let maximumAmount {
                FeaturedSnapCard(
                    entry: entry,
                    imageSize: TodayCanvasLayout.imageSize(for: entry, maximumAmount: maximumAmount),
                    layout: .landscape
                )
                .position(x: availableWidth * 0.357, y: 276)
            }
            if let entry = summary.featuredEntries[safe: 1], let maximumAmount {
                FeaturedSnapCard(
                    entry: entry,
                    imageSize: TodayCanvasLayout.imageSize(for: entry, maximumAmount: maximumAmount),
                    layout: .portrait
                )
                .position(x: availableWidth * 0.736, y: 303)
            }
            if let entry = summary.featuredEntries[safe: 2] {
                PriceTicket(entry: entry)
                    .rotationEffect(.degrees(-4))
                    .position(x: availableWidth * 0.256, y: 354)
            }
        }
    }

    private func recordButtonAppearance(availableWidth: CGFloat) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .bold))
                .frame(width: 28, height: 28)
                .foregroundStyle(.white)
                .background(.white.opacity(0.18), in: Circle())
            Text("기록하기")
                .font(.moneySnap(size: 20, weight: .bold))
        }
        .foregroundStyle(.white)
        .frame(width: 165, height: 64)
        .background(MoneySnapVisualSystem.charcoal, in: Capsule())
        .shadow(color: .black.opacity(0.18), radius: 14, y: 10)
        .accessibilityHidden(true)
        .position(x: availableWidth / 2, y: 436)
    }

    private func pageIndicator(availableWidth: CGFloat) -> some View {
        HStack(spacing: 4) {
            Circle().fill(MoneySnapVisualSystem.ink).frame(width: 5, height: 5)
            Circle().fill(MoneySnapVisualSystem.lightGray).frame(width: 5, height: 5)
        }
        .frame(width: 45, height: 20)
        .background(.white, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .position(x: availableWidth / 2, y: 503)
    }

    private var totalSection: some View {
        Group {
            Text("오늘 총 소비")
                .font(.moneySnap(size: 16, weight: .medium))
                .foregroundStyle(MoneySnapVisualSystem.secondaryText)
                .offset(x: 28, y: 521)
            Text(summary.totalAmount.wonText)
                .font(.moneySnap(size: 64, weight: .black))
                .foregroundStyle(.black)
                .frame(height: 78, alignment: .topLeading)
                .offset(x: 24, y: 533)
        }
    }

    private var recentSection: some View {
        Group {
            Text("오늘 소비")
                .font(.moneySnap(size: 17, weight: .bold))
                .foregroundStyle(MoneySnapVisualSystem.ink)
                .offset(x: 26, y: 612)
            HStack(spacing: 0) {
                ForEach(summary.recentEntries) { entry in
                    RecentSnapRow(entry: entry)
                }
            }
            .offset(x: 26, y: 650)
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    TodaySnapView(client: InMemorySnapJournalClient.fixture)
}
