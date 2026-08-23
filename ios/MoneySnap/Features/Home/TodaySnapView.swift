import SwiftUI

struct TodaySnapView: View {
    let viewModel: TodaySnapViewModel
    let onRecord: () -> Void
    var onOpen: (UUID) -> Void = { _ in }
    var groups: [MoneySnapGroup] = []
    var groupClient: (any GroupClient)?
    var media: (any MediaClient)?

    var body: some View {
        ZStack {
            Color.white

            switch viewModel.state {
            case .loading:
                ProgressView()
                    .accessibilityIdentifier("home.loading")
            case let .content(summary):
                TodaySnapContent(
                    summary: summary,
                    onRecord: onRecord,
                    onOpen: onOpen,
                    groups: groups,
                    groupClient: groupClient,
                    media: media
                )
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
}

private struct TodaySnapContent: View {
    let summary: TodaySnapSummary
    let onRecord: () -> Void
    var onOpen: (UUID) -> Void = { _ in }
    var groups: [MoneySnapGroup] = []
    var groupClient: (any GroupClient)?
    var media: (any MediaClient)?
    @State private var page = 0
    @State private var groupEntries: [UUID: [TodaySnapEntry]] = [:]

    private var orderedGroups: [MoneySnapGroup] {
        GroupCanvasOrder.apply(groups)
    }

    private var pageCount: Int { 1 + orderedGroups.count }
    private var isVisualHome: Bool {
        ProcessInfo.processInfo.environment["MONEYSNAP_VISUAL_SCENARIO"] != nil
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                header(availableWidth: proxy.size.width)
                canvasPages(size: proxy.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                recordButton(availableWidth: proxy.size.width)
                pageIndicator(availableWidth: proxy.size.width)
                totalSection
                recentSection
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task {
            await loadVisibleGroupIfNeeded()
        }
        .onChange(of: page) { _, _ in
            Task { await loadVisibleGroupIfNeeded() }
        }
        .onChange(of: groups.map(\.id)) { _, _ in
            Task { await loadVisibleGroupIfNeeded() }
        }
    }

    @ViewBuilder
    private func canvasPages(size: CGSize) -> some View {
        if isVisualHome || orderedGroups.isEmpty {
            personalCanvas(size: size)
        } else {
            TabView(selection: $page) {
                personalCanvas(size: size).tag(0)
                ForEach(Array(orderedGroups.enumerated()), id: \.element.id) { index, group in
                    TodayCanvasView(
                        entries: groupEntries[group.id] ?? [],
                        maximumAmount: group.amountVisible
                            ? (groupEntries[group.id] ?? []).map(\.amount).max()
                            : nil,
                        canvasSize: size,
                        onOpen: { _ in }
                    )
                    .tag(index + 1)
                    .accessibilityIdentifier("home.group.\(group.id.uuidString.lowercased())")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
    }

    private func personalCanvas(size: CGSize) -> some View {
        TodayCanvasView(
            entries: summary.entries,
            maximumAmount: summary.entries.map(\.amount).max(),
            canvasSize: size,
            onOpen: onOpen
        )
    }

    private func loadVisibleGroupIfNeeded() async {
        guard page > 0, let groupClient, orderedGroups.indices.contains(page - 1) else { return }
        let group = orderedGroups[page - 1]
        if groupEntries[group.id] != nil { return }
        let entries: [TodaySnapEntry]
        if group.amountVisible {
            let today = (try? await groupClient.visibleToday(groupID: group.id)) ?? VisibleGroupToday(localDay: "", members: [])
            entries = today.members.compactMap { member in
                guard let snap = member.representative,
                      let amount = try? KrwAmount(snap.amountWon) else { return nil }
                return TodaySnapEntry(
                    id: snap.snapId,
                    category: snap.category,
                    amount: amount,
                    imageRef: snap.imageRef
                )
            }
        } else {
            let today = (try? await groupClient.hiddenToday(groupID: group.id)) ?? HiddenGroupToday(localDay: "", members: [])
            entries = today.members.compactMap { member in
                guard let snap = member.representative, let amount = try? KrwAmount(1) else { return nil }
                return TodaySnapEntry(
                    id: snap.snapId,
                    category: snap.category,
                    amount: amount,
                    imageRef: snap.imageRef,
                    revealsAmount: false
                )
            }
        }
        var hydrated = entries
        if let media {
            var jpegs: [UUID: Data] = [:]
            await withTaskGroup(of: (UUID, Data?).self) { taskGroup in
                for entry in entries {
                    guard let imageRef = entry.imageRef else { continue }
                    taskGroup.addTask { (entry.id, try? await media.fetchJPEG(imageRef)) }
                }
                for await (id, jpeg) in taskGroup {
                    if let jpeg, jpeg.starts(with: [0xFF, 0xD8, 0xFF]) {
                        jpegs[id] = jpeg
                    }
                }
            }
            hydrated = entries.map { entry in
                guard let jpeg = jpegs[entry.id] else { return entry }
                return TodaySnapEntry(
                    id: entry.id,
                    category: entry.category,
                    amount: entry.amount,
                    imageRef: entry.imageRef,
                    previewJPEG: jpeg,
                    revealsAmount: entry.revealsAmount
                )
            }
        }
        groupEntries[group.id] = hydrated
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

    private func recordButton(availableWidth: CGFloat) -> some View {
        Button(action: onRecord) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .bold))
                    .frame(width: 22, height: 22)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.18), in: Circle())
                Text("기록하기")
                    .font(.moneySnap(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(
                width: TodayCanvasPlacement.recordButtonWidth,
                height: TodayCanvasPlacement.recordButtonHeight
            )
            .background(MoneySnapVisualSystem.charcoal, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 14, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home.record")
        .position(x: availableWidth / 2, y: TodayCanvasPlacement.recordButtonCenterY)
    }

    private func pageIndicator(availableWidth: CGFloat) -> some View {
        let count = isVisualHome ? 2 : pageCount
        return HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == page ? MoneySnapVisualSystem.ink : MoneySnapVisualSystem.lightGray)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(minWidth: 45, minHeight: 20)
        .padding(.horizontal, 10)
        .background(.white, in: Capsule())
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .position(x: availableWidth / 2, y: 503)
        .accessibilityIdentifier("home.pager")
        .opacity(isVisualHome || count > 1 ? 1 : 0)
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

#if DEBUG
#Preview {
    TodaySnapView(
        viewModel: TodaySnapViewModel(client: VisualTestSupport.snapJournalClient),
        onRecord: {},
        onOpen: { _ in }
    )
}
#endif
