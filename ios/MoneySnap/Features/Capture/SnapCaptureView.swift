import SwiftUI
import UIKit

struct SnapCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: SnapCaptureModel
    @State private var confirmsAbandon = false
    @AccessibilityFocusState private var voiceOverFocus: SnapCaptureModel.FocusTarget?
    let onSaved: (SnapRecordReceipt) -> Void

    init(model: SnapCaptureModel, onSaved: @escaping (SnapRecordReceipt) -> Void) {
        _model = State(initialValue: model)
        self.onSaved = onSaved
    }

    var body: some View {
        Group {
            switch model.phase {
            case .category:
                categoryStep
            case .amount:
                amountStep
            }
        }
        .presentationDetents(model.phase == .category ? [.height(214)] : [.height(374)])
        .presentationDragIndicator(.hidden)
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
                    stepPill("1/2")
                }
                .padding(.horizontal, 24)
                .padding(.top, 7)

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
        guard let receipt = await model.submit() else { return }
        onSaved(receipt)
        dismiss()
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
