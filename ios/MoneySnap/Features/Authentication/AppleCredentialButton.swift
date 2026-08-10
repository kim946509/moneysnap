import AuthenticationServices
import CryptoKit
import Security
import SwiftUI

struct AppleCredentialButton: View {
    let onCredential: (AppleSignInCredential) -> Void
    let onFailure: () -> Void

    @State private var requestedNonce: String?

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            do {
                let challenge = try AppleNonce.challenge()
                requestedNonce = challenge.serverNonce
                request.nonce = challenge.appleRequestNonce
            } catch {
                requestedNonce = nil
                onFailure()
            }
        } onCompletion: { result in
            guard
                case let .success(authorization) = result,
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let identityTokenData = credential.identityToken,
                let authorizationCodeData = credential.authorizationCode,
                let identityToken = String(data: identityTokenData, encoding: .utf8),
                let authorizationCode = String(data: authorizationCodeData, encoding: .utf8),
                let requestedNonce
            else {
                onFailure()
                return
            }
            onCredential(AppleSignInCredential(
                identityToken: identityToken,
                authorizationCode: authorizationCode,
                nonce: requestedNonce
            ))
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("Apple로 계속하기")
    }
}

enum AppleNonce {
    static func challenge() throws -> AppleNonceChallenge {
        let rawNonce = try make()
        return AppleNonceChallenge(
            serverNonce: rawNonce,
            appleRequestNonce: hash(rawNonce)
        )
    }

    static func make() throws -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            throw AppleNonceError.randomGenerationFailed
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func hash(_ nonce: String) -> String {
        SHA256.hash(data: Data(nonce.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

struct AppleNonceChallenge: Equatable, Sendable {
    let serverNonce: String
    let appleRequestNonce: String
}

private enum AppleNonceError: Error {
    case randomGenerationFailed
}
