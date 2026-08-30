import SwiftUI
import UIKit

struct SnapDetailView: View {
    @State private var model: SnapDetailModel
    @State private var confirmsDelete = false
    @State private var shareMessage: String?
    let onChanged: (SnapDetail) -> Void
    let onDeleted: () -> Void
    var groups: [MoneySnapGroup] = []
    var onShare: (UUID) -> Void = { _ in }

    init(
        model: SnapDetailModel,
        onChanged: @escaping (SnapDetail) -> Void,
        onDeleted: @escaping () -> Void,
        groups: [MoneySnapGroup] = [],
        onShare: @escaping (UUID) -> Void = { _ in }
    ) {
        _model = State(initialValue: model)
        self.onChanged = onChanged
        self.onDeleted = onDeleted
        self.groups = groups
        self.onShare = onShare
    }

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView()
                    .accessibilityIdentifier("snap.detail.loading")
            case .failure:
                ContentUnavailableView {
                    Label("기록을 불러오지 못했어요", systemImage: "exclamationmark.triangle")
                } actions: {
                    Button("다시 시도") { Task { await model.load() } }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("snap.detail.retry")
                }
            case .gone:
                ContentUnavailableView("이 기록은 더 이상 볼 수 없어요", systemImage: "trash")
                    .accessibilityIdentifier("snap.detail.gone")
                    .task { onDeleted() }
            case let .content(detail):
                detailForm(detail)
            }
        }
        .navigationTitle("Snap 상세")
        .task { await model.load() }
        .alert("공유", isPresented: Binding(
            get: { shareMessage != nil },
            set: { if !$0 { shareMessage = nil } }
        )) {
            Button("확인", role: .cancel) { shareMessage = nil }
        } message: {
            Text(shareMessage ?? "")
        }
        .confirmationDialog("이 기록을 삭제할까요? 오늘 화면에서도 바로 사라집니다.", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                Task {
                    if await model.delete() {
                        onDeleted()
                    }
                }
            }
            Button("취소", role: .cancel) {}
        }
    }

    private func detailForm(_ detail: SnapDetail) -> some View {
        Form {
            if let jpeg = model.previewJPEG, let image = UIImage(data: jpeg) {
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .accessibilityIdentifier("snap.detail.photo")
                }
            }
            Section("날짜") {
                Text(detail.localDay)
                    .accessibilityIdentifier("snap.detail.day")
            }
            Section("카테고리") {
                Picker("카테고리", selection: Binding(
                    get: { model.draftCategory ?? detail.category },
                    set: { model.draftCategory = $0 }
                )) {
                    ForEach(SnapCategory.allCases, id: \.self) { category in
                        Text(category.title).tag(category)
                    }
                }
                .accessibilityIdentifier("snap.detail.category")
            }
            Section("금액") {
                TextField("금액", text: $model.draftAmount)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("snap.detail.amount")
            }
            if let failure = model.failure {
                Section {
                    Text(failure.isRetryable ? "저장 결과를 확인하지 못했어요" : "이 변경은 적용되지 않았어요")
                    if case .versionConflict = failure {
                        Button("최신 내용 다시 불러오기") { Task { await model.load() } }
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
            Section {
                Button("저장") {
                    Task {
                        if let updated = await model.save() {
                            onChanged(updated)
                        }
                    }
                }
                .disabled(model.isSaving)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("snap.detail.save")
                Button("삭제", role: .destructive) { confirmsDelete = true }
                    .disabled(model.isDeleting)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("snap.detail.delete")
            }
            if !groups.isEmpty {
                Section("그룹에 공유") {
                    ForEach(groups) { group in
                        Button(group.name) {
                            onShare(group.id)
                            shareMessage = "\(group.name)에 공유했어요"
                        }
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
            }
        }
        .accessibilityIdentifier("screen.snap.detail")
    }
}
/*

struct SnapDetailView: View {
    let presentation: SnapDetailPresentation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                detailHeader
                hero
                amount
                detailCards
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 48)
        }
        .background(Color.white)
        .navigationTitle("Snap 상세")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("screen.snap-detail")
    }

    private var detailHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("나의 Snap")
                .font(.moneySnap(size: 13, weight: .bold))
                .foregroundStyle(MoneySnapVisualSystem.secondaryText)
            Text("그날의 소비를 다시 봐요")
                .font(.moneySnap(size: 24, weight: .bold))
                .foregroundStyle(MoneySnapVisualSystem.ink)
        }
    }

    private var hero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(MoneySnapVisualSystem.profileNeutralFill.opacity(0.7))
                .rotationEffect(.degrees(5))
                .padding(18)

            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.black.opacity(0.06))
                }
                .shadow(color: .black.opacity(0.08), radius: 16, y: 10)
                .rotationEffect(.degrees(-2.5))
                .padding(12)

            artwork
                .frame(width: 238, height: 238)
                .rotationEffect(.degrees(2))
        }
        .frame(maxWidth: .infinity)
        .frame(height: 310)
        .background(MoneySnapVisualSystem.profileNeutralFill.opacity(0.5), in: RoundedRectangle(cornerRadius: 30))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(presentation.entry.category.title) Snap")
    }

    @ViewBuilder
    private var artwork: some View {
        if let artwork = presentation.entry.artwork {
            Image(artwork.rawValue)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 22))
        } else {
            SnapCategoryPlaceholder(entry: presentation.entry, surface: .detail)
        }
    }

    private var amount: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("소비 금액")
                .font(.moneySnap(size: 13, weight: .medium))
                .foregroundStyle(MoneySnapVisualSystem.secondaryText)
            Text(presentation.entry.amount.value.wonText)
                .font(.moneySnap(size: 46, weight: .black))
                .foregroundStyle(MoneySnapVisualSystem.ink)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .accessibilityIdentifier("snap-detail.amount")
        }
    }

    private var detailCards: some View {
        VStack(spacing: 12) {
            DetailInfoCard(
                systemImage: "square.grid.2x2",
                label: "카테고리",
                value: presentation.entry.category.title
            )
            DetailInfoCard(
                systemImage: "calendar",
                label: "기록일",
                value: presentation.day.displayLabel
            )
        }
    }
}

struct SnapDetailUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "Snap을 찾을 수 없어요",
            systemImage: "exclamationmark.triangle",
            description: Text("홈으로 돌아가 기록을 새로고침해 주세요.")
        )
        .navigationTitle("Snap 상세")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("screen.snap-detail-unavailable")
    }
}

private struct DetailInfoCard: View {
    let systemImage: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(MoneySnapVisualSystem.charcoal)
                .frame(width: 44, height: 44)
                .background(MoneySnapVisualSystem.profileNeutralFill, in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.moneySnap(size: 12, weight: .medium))
                    .foregroundStyle(MoneySnapVisualSystem.secondaryText)
                Text(value)
                    .font(.moneySnap(size: 16, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 72)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.black.opacity(0.06))
        }
        .shadow(color: .black.opacity(0.055), radius: 12, y: 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label), \(value)")
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        SnapDetailView(presentation: SnapDetailPresentation(
            entry: VisualTestSupport.homeSummary.entries[0],
            day: VisualTestSupport.homeSummary.day
        ))
    }
}
#endif
*/
