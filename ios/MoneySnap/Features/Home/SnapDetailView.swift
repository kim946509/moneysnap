import SwiftUI
import UIKit

struct SnapDetailView: View {
    @State private var model: SnapDetailModel
    @State private var confirmsDelete = false
    @FocusState private var amountFocused: Bool
    let onChanged: (SnapDetail) -> Void
    let onDeleted: () -> Void

    init(
        model: SnapDetailModel,
        onChanged: @escaping (SnapDetail) -> Void,
        onDeleted: @escaping () -> Void
    ) {
        _model = State(initialValue: model)
        self.onChanged = onChanged
        self.onDeleted = onDeleted
    }

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView().accessibilityIdentifier("snap.detail.loading")
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
                detailSurface(detail)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .principal) {
                if case let .content(detail) = model.state {
                    Text(detail.localDay)
                        .font(.moneySnap(size: 15, weight: .semibold))
                        .foregroundStyle(MoneySnapVisualSystem.ink)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                if case .content = model.state {
                    Button {
                        confirmsDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .disabled(model.isDeleting)
                    .accessibilityIdentifier("snap.detail.delete")
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("완료") {
                    amountFocused = false
                    Task { await commitAmount() }
                }
                .accessibilityIdentifier("snap.detail.amount.done")
            }
        }
        .confirmationDialog("이 기록을 삭제할까요? 오늘 화면에서도 바로 사라집니다.", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                Task { if await model.delete() { onDeleted() } }
            }
            Button("취소", role: .cancel) {}
        }
    }

    private func detailSurface(_ detail: SnapDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                photoCard(detail)
                amountBlock
                categoryChips(detail)
                if let failure = model.failure { failureCard(failure) }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 48)
        }
        .background(MoneySnapVisualSystem.pageFill)
        .accessibilityIdentifier("screen.snap.detail")
    }

    private func photoCard(_ detail: SnapDetail) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.white)
                .shadow(color: .black.opacity(0.10), radius: 22, y: 12)
                .rotationEffect(.degrees(-2.4))
                .offset(x: 6, y: 8)
            VStack(spacing: 0) {
                photo(detail)
                    .frame(maxWidth: .infinity)
                    .frame(height: 268)
                    .clipped()
                HStack {
                    Text(detail.category.title)
                        .font(.moneySnap(size: 13, weight: .semibold))
                        .foregroundStyle(MoneySnapVisualSystem.secondaryText)
                    Spacer()
                    Text(detail.localDay)
                        .font(.moneySnap(size: 13, weight: .medium))
                        .foregroundStyle(MoneySnapVisualSystem.secondaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 18, y: 10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 318)
        .accessibilityLabel("\(detail.category.title) Snap")
    }

    @ViewBuilder
    private func photo(_ detail: SnapDetail) -> some View {
        if let jpeg = model.previewJPEG, let image = UIImage(data: jpeg) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .accessibilityIdentifier("snap.detail.photo")
        } else {
            DetailCategoryArtwork(category: detail.category)
        }
    }

    private var amountBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("소비 금액")
                .font(.moneySnap(size: 13, weight: .medium))
                .foregroundStyle(MoneySnapVisualSystem.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("₩")
                    .font(.moneySnap(size: 28, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                TextField("0", text: amountDigits)
                    .keyboardType(.numberPad)
                    .font(.moneySnap(size: 44, weight: .black))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                    .focused($amountFocused)
                    .accessibilityIdentifier("snap.detail.amount")
                    .onChange(of: amountFocused) { _, focused in
                        if !focused { Task { await commitAmount() } }
                    }
            }
        }
        .padding(.top, 4)
    }

    private var amountDigits: Binding<String> {
        Binding(
            get: { formattedWon(model.draftAmount) },
            set: { model.draftAmount = $0.filter(\.isNumber) }
        )
    }

    private func categoryChips(_ detail: SnapDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("카테고리")
                .font(.moneySnap(size: 13, weight: .medium))
                .foregroundStyle(MoneySnapVisualSystem.secondaryText)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(SnapCategory.allCases, id: \.self) { category in
                    let selected = (model.draftCategory ?? detail.category) == category
                    Button {
                        Task { await commitCategory(category) }
                    } label: {
                        Text(category.title)
                            .font(.moneySnap(size: 14, weight: selected ? .bold : .medium))
                            .foregroundStyle(selected ? .white : MoneySnapVisualSystem.ink)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 36)
                            .background(
                                selected ? MoneySnapVisualSystem.charcoal : MoneySnapVisualSystem.profileNeutralFill,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .accessibilityIdentifier("snap.detail.category")
        }
    }

    private func failureCard(_ failure: SnapRecordError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(failure.isRetryable ? "저장 결과를 확인하지 못했어요" : "이 변경은 적용되지 않았어요")
            if case .versionConflict = failure {
                Button("최신 내용 다시 불러오기") { Task { await model.load() } }
            }
        }
        .font(.moneySnap(size: 14, weight: .medium))
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
    }

    private func commitCategory(_ category: SnapCategory) async {
        amountFocused = false
        if let updated = await model.selectCategory(category) {
            onChanged(updated)
        }
    }

    private func commitAmount() async {
        if let updated = await model.commitDraft() {
            onChanged(updated)
        }
    }

    private func formattedWon(_ digits: String) -> String {
        guard let value = Int64(digits), value > 0 else { return digits }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: NSNumber(value: value)) ?? digits
    }
}

private struct DetailCategoryArtwork: View {
    let category: SnapCategory
    var body: some View {
        ZStack {
            MoneySnapVisualSystem.profileNeutralFill
            Image(systemName: category.placeholderSymbol)
                .font(.system(size: 64, weight: .medium))
                .foregroundStyle(MoneySnapVisualSystem.charcoal)
        }
    }
}
