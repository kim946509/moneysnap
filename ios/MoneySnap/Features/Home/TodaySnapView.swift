import SwiftUI

struct TodaySnapView: View {
    let viewModel: TodaySnapViewModel
    let onRecord: () -> Void
    var onOpen: (UUID) -> Void = { _ in }

    var body: some View {
        ZStack {
            Color.white

            switch viewModel.state {
            case .loading:
                ProgressView()
                    .accessibilityIdentifier("home.loading")
            case let .empty(day):
                emptyState(day: day)
            case let .content(summary):
                TodaySnapContent(summary: summary, onRecord: onRecord, onOpen: onOpen)
                    .refreshable { await viewModel.refresh() }
                    .overlay(alignment: .top) {
                        if viewModel.refreshFailure {
                            Button("다시 불러오기") {
                                Task { await viewModel.retry() }
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("home.refresh-retry")
                            .padding(.top, 72)
                        }
                    }
            case .failure:
                ContentUnavailableView {
                    Label("오늘 기록을 불러오지 못했어요", systemImage: "exclamationmark.arrow.triangle.2.circlepath")
                        .accessibilityIdentifier("screen.home")
                } actions: {
                    Button("다시 시도") {
                        Task { await viewModel.retry() }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("home.retry")
                }
            }
        }
        .task { await viewModel.load() }
    }

    private func emptyState(day: SnapDay) -> some View {
        ContentUnavailableView {
            Label("오늘 기록이 없어요", systemImage: "plus.circle")
                .accessibilityIdentifier("screen.home")
        } description: {
            Text(day.displayLabel)
        } actions: {
            Button("기록하기", action: onRecord)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("home.record")
        }
    }
}

private struct TodaySnapContent: View {
    let summary: TodaySnapSummary
    let onRecord: () -> Void
    var onOpen: (UUID) -> Void = { _ in }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                header(availableWidth: proxy.size.width)
                featuredCards(availableWidth: proxy.size.width)
                recordButton(availableWidth: proxy.size.width)
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
                    .accessibilityIdentifier("screen.home")
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
                .onTapGesture { onOpen(entry.id) }
                .position(x: availableWidth * 0.357, y: 276)
            }
            if let entry = summary.featuredEntries[safe: 1], let maximumAmount {
                FeaturedSnapCard(
                    entry: entry,
                    imageSize: TodayCanvasLayout.imageSize(for: entry, maximumAmount: maximumAmount),
                    layout: .portrait
                )
                .onTapGesture { onOpen(entry.id) }
                .position(x: availableWidth * 0.736, y: 303)
            }
            if let entry = summary.featuredEntries[safe: 2] {
                PriceTicket(entry: entry)
                    .rotationEffect(.degrees(-4))
                    .position(x: availableWidth * 0.256, y: 354)
            }
        }
    }

    private func recordButton(availableWidth: CGFloat) -> some View {
        Button(action: onRecord) {
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
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.record")
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
                .accessibilityIdentifier("home.total")
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
            HStack(spacing: 28) {
                ForEach(summary.recentEntries) { entry in
                    RecentSnapRow(entry: entry)
                        .onTapGesture { onOpen(entry.id) }
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

#if DEBUG
#Preview {
    TodaySnapView(
        viewModel: TodaySnapViewModel(client: VisualTestSupport.snapJournalClient),
        onRecord: {},
        onOpen: { _ in }
    )
}
#endif
