import SwiftUI

struct ArchiveView: View {
    @State private var viewModel: ArchiveViewModel
    var onOpen: (UUID) -> Void = { _ in }

    init(client: any SnapJournalClient, onOpen: @escaping (UUID) -> Void = { _ in }) {
        _viewModel = State(initialValue: ArchiveViewModel(client: client))
        self.onOpen = onOpen
    }

    init(viewModel: ArchiveViewModel, onOpen: @escaping (UUID) -> Void = { _ in }) {
        _viewModel = State(initialValue: viewModel)
        self.onOpen = onOpen
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                calendarCard
                daySection
            }
            .padding(.horizontal, 24)
            .padding(.top, 7)
            .padding(.bottom, 120)
        }
        .background(Color.white)
        .task { await viewModel.load() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: -2) {
                Text("Archive")
                    .font(.moneySnap(size: 22, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                    .accessibilityIdentifier("screen.archive")
                Text(viewModel.monthTitle)
                    .font(.moneySnap(size: 13, weight: .medium))
                    .foregroundStyle(MoneySnapVisualSystem.secondaryText)
            }
            Spacer()
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(MoneySnapVisualSystem.navy, in: Circle())
                .shadow(color: .black.opacity(0.15), radius: 12, y: 9)
                .accessibilityHidden(true)
        }
    }

    private var calendarCard: some View {
        VStack(spacing: 16) {
            HStack {
                monthButton("chevron.left", label: "이전 달", identifier: "archive.prev-month", value: -1)
                Spacer()
                Text(viewModel.monthTitle)
                    .font(.moneySnap(size: 17, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                Spacer()
                monthButton("chevron.right", label: "다음 달", identifier: "archive.next-month", value: 1)
            }

            HStack(spacing: 0) {
                ForEach(ArchiveCalendar.weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.moneySnap(size: 12, weight: .medium))
                        .foregroundStyle(MoneySnapVisualSystem.secondaryText)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                spacing: 6
            ) {
                ForEach(Array(viewModel.cells.enumerated()), id: \.offset) { _, cell in
                    dayCell(cell)
                }
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity)
        .archiveSurface(cornerRadius: 22)
    }

    private func dayCell(_ cell: ArchiveDayCell) -> some View {
        Group {
            switch cell {
            case .padding:
                Color.clear
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityHidden(true)
            case let .day(localDay, dayNumber):
                let isSelected = viewModel.selectedDay == localDay
                let isOccupied = viewModel.occupied.contains(localDay)
                Button {
                    Task { await viewModel.select(day: localDay) }
                } label: {
                    VStack(spacing: 3) {
                        Text("\(dayNumber)")
                            .font(.moneySnap(size: 15, weight: isSelected || isOccupied ? .bold : .medium))
                            .foregroundStyle(isSelected ? Color.white : MoneySnapVisualSystem.ink)
                            .frame(width: 36, height: 36)
                            .background(
                                isSelected ? MoneySnapVisualSystem.navy : Color.clear,
                                in: Circle()
                            )
                        Circle()
                            .fill(isOccupied && !isSelected ? MoneySnapVisualSystem.navy : Color.clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(dayAccessibilityLabel(localDay: localDay, dayNumber: dayNumber, occupied: isOccupied, selected: isSelected))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("archive.day.\(localDay)")
            }
        }
    }

    private var daySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.failed {
                Button("다시 시도") {
                    Task { await viewModel.retry() }
                }
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("archive.retry")
            } else if let empty = viewModel.emptyCopy {
                Text(empty.message)
                    .font(.moneySnap(size: 15, weight: .medium))
                    .foregroundStyle(MoneySnapVisualSystem.secondaryText)
                    .accessibilityIdentifier(empty == .emptyMonth ? "archive.empty-month" : "archive.empty-day")
            } else {
                Text(viewModel.selectedDayLabel)
                    .font(.moneySnap(size: 17, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                    .accessibilityIdentifier("archive.day-title")
                Text(viewModel.selectedDayTotal.wonText)
                    .font(.moneySnap(size: 40, weight: .black))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                    .accessibilityIdentifier("archive.total")
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.snaps) { entry in
                        Button {
                            onOpen(entry.id)
                        } label: {
                            HStack {
                                RecentSnapRow(entry: entry)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(MoneySnapVisualSystem.secondaryText)
                            }
                            .padding(.horizontal, 17)
                            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                            .archiveSurface(cornerRadius: 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func monthButton(
        _ systemName: String,
        label: String,
        identifier: String,
        value: Int
    ) -> some View {
        Button {
            Task { await viewModel.shiftMonth(value) }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MoneySnapVisualSystem.ink)
                .frame(width: 44, height: 44)
                .background(MoneySnapVisualSystem.profileNeutralFill, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private func dayAccessibilityLabel(
        localDay: String,
        dayNumber: Int,
        occupied: Bool,
        selected: Bool
    ) -> String {
        var label = "\(dayNumber)일"
        if occupied { label += ", 기록 있음" }
        if selected { label += ", 선택됨" }
        _ = localDay
        return label
    }
}

struct ArchivePage: Equatable, Sendable {
    var snaps: [TodaySnapEntry]
    var nextCursor: String?
    var occupiedLocalDays: [String]?
}

private extension View {
    func archiveSurface(cornerRadius: CGFloat) -> some View {
        background(.white, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MoneySnapVisualSystem.profileBorder)
            }
    }
}

#if DEBUG
#Preview {
    ArchiveView(client: VisualTestSupport.snapJournalClient)
}
#endif
