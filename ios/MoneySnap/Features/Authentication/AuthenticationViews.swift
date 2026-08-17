import SwiftUI

struct AuthenticationGateView: View {
    let authentication: AuthenticationModel
    @Binding var selectedTab: AppTab
    let snapJournalClient: any SnapJournalClient
    var groupClient: any GroupClient = UnavailableGroupClient()
    var mediaClient: (any MediaClient)? = nil
    var initialCaptureModel: SnapCaptureModel?

    var body: some View {
        Group {
            switch authentication.phase {
            case .restoring:
                ZStack {
                    Color.white.ignoresSafeArea()
                    ProgressView("로그인 상태 확인 중")
                        .tint(MoneySnapVisualSystem.navy)
                }
            case .signedOut:
                LoginView(authentication: authentication)
            case .restoreFailed:
                SessionRecoveryView(authentication: authentication)
            case .authenticated:
                AppShellView(
                    selectedTab: $selectedTab,
                    authentication: authentication,
                    snapJournalClient: snapJournalClient,
                    groupClient: groupClient,
                    mediaClient: mediaClient,
                    initialCaptureModel: initialCaptureModel
                )
            }
        }
        .task {
            if authentication.phase == .restoring {
                await authentication.restore()
            }
        }
    }
}

private struct LoginView: View {
    let authentication: AuthenticationModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(MoneySnapVisualSystem.navy, in: Circle())
                    .accessibilityHidden(true)
                Text("Money Snap")
                    .font(.moneySnap(size: 32, weight: .black))
                    .foregroundStyle(MoneySnapVisualSystem.ink)
                Text("오늘의 소비를 가볍게 기록해요")
                    .font(.moneySnap(size: 15, weight: .medium))
                    .foregroundStyle(MoneySnapVisualSystem.secondaryText)
            }

            Spacer()

            VStack(spacing: 14) {
                if authentication.issue == .signInFailed {
                    Text("로그인하지 못했어요. 다시 시도해 주세요.")
                        .font(.moneySnap(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                }
                if authentication.issue == .localSessionCleanupFailed {
                    Text("계정 처리는 완료됐지만 이 기기의 이전 로그인 정보를 정리하지 못했어요.")
                        .font(.moneySnap(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
                AppleCredentialButton { credential in
                    Task { await authentication.signIn(with: credential) }
                } onFailure: {
                    authentication.reportAppleAuthorizationFailure()
                }
                .disabled(authentication.isWorking)

                Text("계속하면 Money Snap의 개인정보 처리방침에 동의하게 됩니다.")
                    .font(.moneySnap(size: 11, weight: .medium))
                    .foregroundStyle(MoneySnapVisualSystem.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .background(Color.white.ignoresSafeArea())
    }
}

private struct SessionRecoveryView: View {
    let authentication: AuthenticationModel

    private var description: String {
        if authentication.issue == .localSessionPersistenceFailed {
            return "새 로그인 정보를 안전하게 저장하지 못했어요. 다시 로그인해 주세요."
        }
        return "저장된 로그인 정보는 유지했어요. 연결을 확인하고 다시 시도해 주세요."
    }

    var body: some View {
        ContentUnavailableView {
            Label("로그인 상태를 확인할 수 없어요", systemImage: "wifi.exclamationmark")
        } description: {
            Text(description)
        } actions: {
            Button("다시 시도") {
                Task { await authentication.restore() }
            }
            .buttonStyle(.borderedProminent)
            .tint(MoneySnapVisualSystem.navy)
        }
    }
}

struct AccountSettingsView: View {
    let authentication: AuthenticationModel

    @Environment(\.dismiss) private var dismiss
    @State private var presentsAccountDeletion = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("현재 기기에서 로그아웃") {
                        Task { await authentication.logout() }
                    }
                    .disabled(authentication.isWorking)

                    Button("계정 탈퇴", role: .destructive) {
                        presentsAccountDeletion = true
                    }
                    .disabled(authentication.isWorking)
                } header: {
                    Text("계정")
                } footer: {
                    Text("탈퇴하면 모든 개인·공유 기록이 삭제되고 Apple 사용 승인도 철회됩니다.")
                }

                if authentication.issue == .logoutFailed {
                    Section {
                        Label("로그아웃하지 못했어요. 연결을 확인해 주세요.", systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("앱 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $presentsAccountDeletion) {
                AccountDeletionReauthenticationView(authentication: authentication)
            }
        }
    }
}

private struct AccountDeletionReauthenticationView: View {
    let authentication: AuthenticationModel

    @Environment(\.dismiss) private var dismiss
    @State private var credentialForDeletion: AppleSignInCredential?
    @State private var confirmsDeletion = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("마지막으로 Apple 계정을 확인해 주세요")
                    .font(.moneySnap(size: 22, weight: .bold))
                Text("재인증이 완료된 뒤에만 Money Snap 계정과 모든 연결 데이터를 삭제합니다.")
                    .font(.moneySnap(size: 14, weight: .medium))
                    .foregroundStyle(MoneySnapVisualSystem.secondaryText)

                if authentication.issue == .accountDeletionFailed {
                    Text("계정 삭제 결과를 확인하지 못했어요. 연결을 확인한 뒤 다시 로그인해 주세요.")
                        .font(.moneySnap(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                }

                if authentication.issue == .accountReauthenticationFailed {
                    Text("Apple 계정을 확인하지 못했어요. 다시 시도해 주세요.")
                        .font(.moneySnap(size: 13, weight: .medium))
                        .foregroundStyle(.red)
                }

                Spacer()

                AppleCredentialButton { credential in
                    credentialForDeletion = credential
                    confirmsDeletion = true
                } onFailure: {
                    authentication.reportAccountDeletionAuthorizationFailure()
                }
                .disabled(authentication.isWorking)
            }
            .padding(24)
            .navigationTitle("계정 탈퇴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .alert("Money Snap 계정을 탈퇴할까요?", isPresented: $confirmsDeletion) {
                Button("취소", role: .cancel) {
                    credentialForDeletion = nil
                }
                Button("모든 데이터 삭제", role: .destructive) {
                    guard let credentialForDeletion else { return }
                    Task { await authentication.deleteAccount(with: credentialForDeletion) }
                }
            } message: {
                Text("모든 개인·공유 기록과 그룹 연결이 삭제되고 Apple 사용 승인이 철회됩니다. 이 작업은 되돌릴 수 없습니다.")
            }
        }
    }
}
