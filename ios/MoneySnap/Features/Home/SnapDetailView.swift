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
        .navigationTitle("Snap 상세")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .alert("공유", isPresented: Binding(get: { shareMessage != nil }, set: { if !$0 { shareMessage = nil } })) {
            Button("확인", role: .cancel) { shareMessage = nil }
        } message: { Text(shareMessage ?? "") }
        .confirmationDialog("이 기록을 삭제할까요? 오늘 화면에서도 바로 사라집니다.", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                Task { if await model.delete() { onDeleted() } }
            }
            Button("취소", role: .cancel) {}
        }
    }

    private func detailSurface(_ detail: SnapDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero(detail)
                amountEditor(detail)
                metadataEditor(detail)
                if let failure = model.failure { failureCard(failure) }
                actions
                if !groups.isEmpty { shareSection }
            }
            .padding(20)
            .padding(.bottom, 38)
        }
        .background(MoneySnapVisualSystem.profileNeutralFill.opacity(0.38))
        .accessibilityIdentifier("screen.snap.detail")
    }

    private func hero(_ detail: SnapDetail) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(MoneySnapVisualSystem.profileNeutralFill.opacity(0.9))
                .rotationEffect(.degrees(4))
                .padding(16)
            RoundedRectangle(cornerRadius: 30)
                .fill(.white)
                .shadow(color: .black.opacity(0.09), radius: 16, y: 9)
                .rotationEffect(.degrees(-2.2))
                .padding(10)
            if let jpeg = model.previewJPEG, let image = UIImage(data: jpeg) {
                Image(uiImage: image)
                    .resizable().scaledToFill().frame(width: 224, height: 224)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .accessibilityIdentifier("snap.detail.photo")
            } else {
                DetailCategoryArtwork(category: detail.category)
                    .frame(width: 224, height: 224)
            }
        }
        .frame(maxWidth: .infinity).frame(height: 286)
        .accessibilityLabel("\(detail.category.title) Snap")
    }

    private func amountEditor(_ detail: SnapDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("소비 금액").font(.moneySnap(size: 13, weight: .medium)).foregroundStyle(MoneySnapVisualSystem.secondaryText)
            TextField("금액", text: $model.draftAmount)
                .keyboardType(.numberPad)
                .font(.moneySnap(size: 42, weight: .black))
                .foregroundStyle(MoneySnapVisualSystem.ink)
                .accessibilityIdentifier("snap.detail.amount")
        }
        .padding(18).background(.white, in: RoundedRectangle(cornerRadius: 22))
    }

    private func metadataEditor(_ detail: SnapDetail) -> some View {
        VStack(spacing: 12) {
            DetailRow(icon: "calendar", label: "기록일") { Text(detail.localDay) }
            DetailRow(icon: "square.grid.2x2", label: "카테고리") {
                Picker("카테고리", selection: Binding(get: { model.draftCategory ?? detail.category }, set: { model.draftCategory = $0 })) {
                    ForEach(SnapCategory.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden().accessibilityIdentifier("snap.detail.category")
            }
        }
    }

    private func failureCard(_ failure: SnapRecordError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(failure.isRetryable ? "저장 결과를 확인하지 못했어요" : "이 변경은 적용되지 않았어요")
            if case .versionConflict = failure {
                Button("최신 내용 다시 불러오기") { Task { await model.load() } }
            }
        }
        .font(.moneySnap(size: 14, weight: .medium)).padding(16)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button("저장") { Task { if let updated = await model.save() { onChanged(updated) } } }
                .disabled(model.isSaving).buttonStyle(DetailPrimaryButton()).accessibilityIdentifier("snap.detail.save")
            Button("삭제", role: .destructive) { confirmsDelete = true }
                .disabled(model.isDeleting).frame(maxWidth: .infinity, minHeight: 48)
                .background(.white, in: RoundedRectangle(cornerRadius: 16)).accessibilityIdentifier("snap.detail.delete")
        }
    }

    private var shareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("그룹에 공유").font(.moneySnap(size: 16, weight: .bold))
            ForEach(groups) { group in
                Button(group.name) { onShare(group.id); shareMessage = "\(group.name)에 공유했어요" }
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).padding(.horizontal, 16)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

private struct DetailCategoryArtwork: View {
    let category: SnapCategory
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24).fill(MoneySnapVisualSystem.profileNeutralFill)
            Image(systemName: category.placeholderSymbol).font(.system(size: 64, weight: .medium)).foregroundStyle(MoneySnapVisualSystem.charcoal)
        }
    }
}

private struct DetailRow<Content: View>: View {
    let icon: String
    let label: String
    let content: Content

    init(icon: String, label: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 42, height: 42).background(MoneySnapVisualSystem.profileNeutralFill, in: RoundedRectangle(cornerRadius: 13))
            Text(label).font(.moneySnap(size: 13, weight: .medium)).foregroundStyle(MoneySnapVisualSystem.secondaryText)
            Spacer(); content.font(.moneySnap(size: 16, weight: .bold))
        }
        .padding(14).background(.white, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct DetailPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.frame(maxWidth: .infinity, minHeight: 50).foregroundStyle(.white)
            .background(MoneySnapVisualSystem.charcoal.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 16))
    }
}
