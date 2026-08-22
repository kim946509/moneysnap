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
