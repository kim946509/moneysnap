import PhotosUI
import SwiftUI
import UIKit

struct SnapCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: SnapCaptureModel
    @State private var confirmsAbandon = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var presentsCamera = false
    @AccessibilityFocusState private var voiceOverFocus: SnapCaptureModel.FocusTarget?
    let onSaved: (SnapRecordReceipt, Data?) -> Void

    init(model: SnapCaptureModel, onSaved: @escaping (SnapRecordReceipt, Data?) -> Void) {
        _model = State(initialValue: model)
        self.onSaved = onSaved
    }

    var body: some View {
        Group {
            switch model.phase {
            case .source:
                sourceStep
            case .category:
                categoryStep
            case .amount:
                amountStep
            case .details:
                detailsStep
            }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(model.layout == .staged ? .hidden : .visible)
        .onAppear { voiceOverFocus = model.focusTarget }
        .onChange(of: model.focusTarget) { _, focusTarget in
            voiceOverFocus = focusTarget
            UIAccessibility.post(
                notification: .announcement,
                argument: model.accessibilityAnnouncement
            )
        }
        .interactiveDismissDisabled(model.requiresAbandonConfirmation || model.isSubmitting)
        .alert("기록을 포기할까요?", isPresented: $confirmsAbandon) {
            Button("계속 입력", role: .cancel) {}
            Button("기록 포기", role: .destructive) { dismiss() }
        } message: {
            Text("저장 결과를 확인하지 못한 기록은 이미 저장됐을 수도 있어요. 다시 기록하면 중복될 수 있습니다.")
        }
    }

    private var sourceStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("사진")
                .font(.moneySnap(size: 24, weight: .bold))
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("screen.record.source")
            Button("사진 없이 기록") { model.skipPhotos() }
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, 24)
                .accessibilityIdentifier("record.source.none")
            PhotosPicker(selection: $photoItems, maxSelectionCount: 3, matching: .images) {
                Text("앨범에서 선택")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .padding(.horizontal, 24)
            .onChange(of: photoItems) { _, items in
                Task { await loadPhotos(items) }
            }
            Button("사진 촬영") { presentsCamera = true }
                .frame(minWidth: 44, minHeight: 44)
                .padding(.horizontal, 24)
                .accessibilityIdentifier("record.source.camera")
                .sheet(isPresented: $presentsCamera) {
                    CameraPicker { image in
                        if let normalized = try? JpegNormalizer.normalize(image) {
                            model.attach([normalized])
                        }
                    }
                    .ignoresSafeArea()
                }
        }
    }

    private var categoryStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    Text("카테고리")
                        .font(.moneySnap(size: 24, weight: .bold))
                        .foregroundStyle(MoneySnapVisualSystem.ink)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($voiceOverFocus, equals: .categoryHeader)
                    Spacer()
                    stepPill(model.photoQueue.progressLabel ?? "1/2")
                }
                .padding(.horizontal, 24)
                .padding(.top, 7)

                categoryGrid
                    .padding(.top, 16)
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("screen.record.category")
    }

    private var amountStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 12) {
                    Button {
                        handleBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .medium))
                            .frame(width: 44, height: 44)
                            .background(MoneySnapVisualSystem.profileNeutralFill, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(model.isSubmitting)
                    .accessibilityLabel("뒤로")
                    .accessibilityIdentifier("record.back")

                    if let category = model.selectedCategory {
                        Text(category.title)
                            .font(.moneySnap(size: 14, weight: .bold))
                            .foregroundStyle(MoneySnapVisualSystem.ink)
                            .frame(minWidth: 72, minHeight: 34)
                            .background(MoneySnapVisualSystem.captureSelectionFill, in: Capsule())
                    }

                    Spacer()
                    stepPill("2/2")
                }

                Text("금액")
                    .font(.moneySnap(size: 15, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.secondaryText)
                    .padding(.top, 10)

                Text(model.amountText)
                    .font(.moneySnap(size: 46, weight: .black))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .center)
                    .accessibilityLabel("금액 \(model.amountText)")
                    .accessibilityIdentifier("record.amount")
                    .accessibilityFocused($voiceOverFocus, equals: .amountHeader)

                if let failure = model.failure {
                    failureView(failure)
                        .frame(maxWidth: .infinity)
                }

                keypad
                    .frame(maxWidth: .infinity)
                    .padding(.top, model.failure == nil ? 20 : 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("screen.record.amount")
    }

    private var detailsStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .center) {
                    if model.photoQueue.current != nil {
                        Button {
                            handleBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 22, weight: .medium))
                                .frame(width: 44, height: 44)
                                .background(MoneySnapVisualSystem.profileNeutralFill, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isSubmitting)
                        .accessibilityLabel("뒤로")
                        .accessibilityIdentifier("record.back")
                    }
                    Text("기록")
                        .font(.moneySnap(size: 24, weight: .bold))
                        .foregroundStyle(MoneySnapVisualSystem.ink)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($voiceOverFocus, equals: .categoryHeader)
                    Spacer()
                    if let progress = model.photoQueue.progressLabel {
                        stepPill(progress)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                if let jpeg = model.photoQueue.current,
                   let image = UIImage(data: jpeg.bytes) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .accessibilityHidden(true)
                }

                Text("카테고리")
                    .font(.moneySnap(size: 15, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.secondaryText)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                categoryGrid
                    .padding(.top, 12)

                Text("금액")
                    .font(.moneySnap(size: 15, weight: .bold))
                    .foregroundStyle(MoneySnapVisualSystem.secondaryText)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)

                Text(model.amountText)
                    .font(.moneySnap(size: 46, weight: .black))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity, minHeight: 64, alignment: .center)
                    .padding(.horizontal, 24)
                    .accessibilityLabel("금액 \(model.amountText)")
                    .accessibilityIdentifier("record.amount")
                    .accessibilityFocused($voiceOverFocus, equals: .amountHeader)

                if let failure = model.failure {
                    failureView(failure)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 24)
                }

                keypad
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, model.failure == nil ? 16 : 8)
                    .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("screen.record.category")
    }

    private var categoryGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(48), spacing: 38), count: 4),
            alignment: .center,
            spacing: 15
        ) {
            ForEach(SnapCategory.allCases, id: \.rawValue) { category in
                Button {
                    model.select(category)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: category.captureSystemImage)
                            .font(.system(size: 21, weight: .medium))
                            .frame(width: 48, height: 48)
                            .background(
                                model.selectedCategory == category
                                    ? Color.white : MoneySnapVisualSystem.profileNeutralFill,
                                in: RoundedRectangle(cornerRadius: 13)
                            )
                            .overlay {
                                if model.selectedCategory == category {
                                    RoundedRectangle(cornerRadius: 13)
                                        .stroke(MoneySnapVisualSystem.ink, lineWidth: 2)
                                }
                            }
                        Text(category.title)
                            .font(.moneySnap(size: 12, weight: .medium))
                            .foregroundStyle(MoneySnapVisualSystem.profileBadgeText)
                    }
                }
                .buttonStyle(.plain)
                .frame(minWidth: 48, minHeight: 70)
                .accessibilityIdentifier("record.category.\(category.rawValue)")
                .accessibilityAddTraits(model.selectedCategory == category ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var detents: Set<PresentationDetent> {
        switch model.phase {
        case .category:
            [.height(214)]
        case .source, .amount:
            [.height(374)]
        case .details:
            [.large]
        }
    }

    private var keypad: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(87), spacing: 15), count: 3),
            spacing: 11
        ) {
            ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9], id: \.self) { digit in
                digitButton(digit)
            }

            Button { model.deleteDigit() } label: {
                Text("지움")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(CaptureKeyButtonStyle())
            .accessibilityLabel("한 자리 지우기")
            .accessibilityIdentifier("record.delete")

            digitButton(0)

            Button {
                Task { await submit() }
            } label: {
                Text(actionTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(CaptureKeyButtonStyle(isPrimary: true))
            .disabled(!model.canSubmit)
            .accessibilityLabel(model.failure?.isRetryable == true ? "같은 기록 다시 확인" : "저장하기")
            .accessibilityIdentifier(model.failure?.isRetryable == true ? "record.retry" : "record.submit")
            .accessibilityFocused($voiceOverFocus, equals: .retryAction)
        }
    }

    private func digitButton(_ digit: Int) -> some View {
        Button { model.appendDigit(digit) } label: {
            Text(String(digit))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(CaptureKeyButtonStyle())
        .accessibilityLabel("\(digit)")
        .accessibilityIdentifier("record.digit.\(digit)")
    }

    @ViewBuilder
    private func failureView(_ failure: SnapRecordError) -> some View {
        VStack(spacing: 4) {
            Text(message(for: failure))
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
            if model.requiresAbandonConfirmation {
                Button("기록 포기") { confirmsAbandon = true }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("record.abandon")
            }
        }
    }

    private func stepPill(_ text: String) -> some View {
        Text(text)
            .font(.moneySnap(size: 11, weight: .medium))
            .foregroundStyle(MoneySnapVisualSystem.secondaryText)
            .frame(width: 42, height: 25)
            .background(MoneySnapVisualSystem.profileNeutralFill, in: Capsule())
            .accessibilityLabel("\(text) 단계")
    }

    private var actionTitle: String {
        if model.isSubmitting { return "저장 중" }
        if model.failure?.isRetryable == true { return "재시도" }
        return "완료"
    }

    private func handleBack() {
        if model.requiresAbandonConfirmation {
            confirmsAbandon = true
        } else if model.hasTerminalFailure {
            dismiss()
        } else {
            model.goBack()
        }
    }

    private func submit() async {
        let previewJPEG = model.photoQueue.current?.bytes
        guard let receipt = await model.submit() else { return }
        onSaved(receipt, previewJPEG)
        if model.photoQueue.photos.isEmpty || model.photoQueue.isFinished {
            dismiss()
        } else {
            model.prepareNextPhoto()
        }
    }

    private func message(for failure: SnapRecordError) -> String {
        switch failure {
        case .invalidRequest:
            "입력 내용을 저장할 수 없어요. 다시 확인해 주세요."
        case .sessionRejected:
            "로그인 시간이 만료됐어요. 다시 로그인해 주세요."
        case let .mutationConflict(correlationID):
            "같은 기록 요청이 달라 저장할 수 없어요. 문의 코드: \(correlationID)"
        case .serverFailure, .transportFailure:
            "저장 결과를 확인하지 못했어요. 같은 기록으로 다시 확인해 주세요."
        case .malformedResponse:
            "저장 응답을 확인하지 못했어요. 같은 기록으로 다시 확인해 주세요."
        case .versionConflict, .notAccessible:
            "이 기록은 더 이상 저장할 수 없어요."
        }
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) async {
        var photos: [NormalizedJpeg] = []
        for item in items.prefix(3) {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let normalized = try? JpegNormalizer.normalize(image)
            else { continue }
            photos.append(normalized)
        }
        if !photos.isEmpty {
            model.attach(photos)
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void

        init(onImage: @escaping (UIImage) -> Void) {
            self.onImage = onImage
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

private struct CaptureKeyButtonStyle: ButtonStyle {
    let isPrimary: Bool

    init(isPrimary: Bool = false) {
        self.isPrimary = isPrimary
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.moneySnap(size: 20, weight: .medium))
            .foregroundStyle(isPrimary ? Color.white : MoneySnapVisualSystem.ink)
            .background(
                isPrimary ? MoneySnapVisualSystem.ink : MoneySnapVisualSystem.captureKeyFill,
                in: RoundedRectangle(cornerRadius: 13)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private extension SnapCategory {
    var captureSystemImage: String {
        switch self {
        case .food: "fork.knife"
        case .cafe: "mug"
        case .transportation: "bus.fill"
        case .shopping: "bag"
        case .living: "house"
        case .culture: "ticket"
        case .health: "cross.case"
        case .other: "ellipsis"
        }
    }
}
