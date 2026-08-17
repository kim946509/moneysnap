import SwiftUI

struct ArchiveView: View {
    let client: any SnapJournalClient
    @State private var month = Date()
    @State private var selectedDay: String?
    @State private var occupied: Set<String> = []
    @State private var snaps: [TodaySnapEntry] = []
    @State private var failed = false
    var onOpen: (UUID) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("이전 달") { shiftMonth(-1) }
                    .frame(minWidth: 44, minHeight: 44)
                Spacer()
                Text(monthTitle)
                    .font(.moneySnap(size: 20, weight: .bold))
                    .accessibilityIdentifier("screen.archive")
                Spacer()
                Button("다음 달") { shiftMonth(1) }
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 20)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(daysInMonth, id: \.self) { day in
                    Button {
                        selectedDay = day
                        Task { await loadDay(day) }
                    } label: {
                        Text(day.suffix(2))
                            .frame(minWidth: 44, minHeight: 44)
                            .background(occupied.contains(day) ? MoneySnapVisualSystem.navy.opacity(0.15) : Color.clear)
                            .overlay {
                                if selectedDay == day {
                                    Circle().stroke(MoneySnapVisualSystem.navy, lineWidth: 2)
                                }
                            }
                    }
                }
            }
            .padding(.horizontal, 16)

            if failed {
                Button("다시 시도") { Task { await loadMonth() } }
                    .frame(minWidth: 44, minHeight: 44)
            } else if let selectedDay, snaps.isEmpty {
                Text("\(selectedDay)에는 기록이 없어요")
                    .padding(.horizontal, 24)
            } else {
                List(snaps) { entry in
                    Button {
                        onOpen(entry.id)
                    } label: {
                        HStack {
                            Text(entry.category.title)
                            Spacer()
                            Text(entry.amount.value.wonText)
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
        }
        .task { await loadMonth() }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: month)
    }

    private var daysInMonth: [String] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else { return [] }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: start).map(Self.isoDay)
        }
    }

    private func shiftMonth(_ value: Int) {
        if let next = Calendar(identifier: .gregorian).date(byAdding: .month, value: value, to: month) {
            month = next
            Task { await loadMonth() }
        }
    }

    private func loadMonth() async {
        guard let first = daysInMonth.first, let last = daysInMonth.last else { return }
        do {
            let page = try await client.archive(from: first, to: last, cursor: nil)
            occupied = Set(page.occupiedLocalDays ?? [])
            failed = false
            if let selectedDay {
                await loadDay(selectedDay)
            }
        } catch {
            failed = true
        }
    }

    private func loadDay(_ day: String) async {
        do {
            let page = try await client.archive(from: day, to: day, cursor: nil)
            snaps = page.snaps
            failed = false
        } catch {
            failed = true
        }
    }

    private static func isoDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

struct ArchivePage: Equatable, Sendable {
    var snaps: [TodaySnapEntry]
    var nextCursor: String?
    var occupiedLocalDays: [String]?
}
