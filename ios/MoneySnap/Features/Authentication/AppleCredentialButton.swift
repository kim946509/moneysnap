import AuthenticationServices
import CryptoKit
import OSLog
import Security
import SwiftUI

struct AppleCredentialButton: View {
    let onCredential: (AppleSignInCredential) -> Void
    let onFailure: () -> Void

    private static let logger = Logger(
        subsystem: "com.ansandy.moneysnap",
        category: "authentication.apple"
    )

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            do {
                let challenge = try AppleNonce.challenge()
                AppleSignInNonce.store(challenge.serverNonce)
                request.requestedScopes = [.fullName, .email]
                request.nonce = challenge.appleRequestNonce
            } catch {
                AppleSignInNonce.clear()
                onFailure()
            }
        } onCompletion: { result in
            guard case let .success(authorization) = result else {
                if case let .failure(error) = result {
                    if let authorizationError = error as? ASAuthorizationError {
                        Self.logger.error(
                            "Apple authorization failed with code \(authorizationError.code.rawValue, privacy: .public)"
                        )
                    } else {
                        Self.logger.error(
                            "Apple authorization failed with code \((error as NSError).code, privacy: .public)"
                        )
                    }
                } else {
                    Self.logger.error("Apple authorization returned an unknown result")
                }
                AppleSignInNonce.clear()
                onFailure()
                return
            }
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let identityTokenData = credential.identityToken,
                let authorizationCodeData = credential.authorizationCode,
                let identityToken = String(data: identityTokenData, encoding: .utf8),
                let authorizationCode = String(data: authorizationCodeData, encoding: .utf8),
                let requestedNonce = AppleSignInNonce.take()
            else {
                Self.logger.error("Apple authorization returned incomplete credential data")
                AppleSignInNonce.clear()
                onFailure()
                return
            }
            Self.logger.debug("Apple authorization returned identity token, code, and nonce")
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

enum AppleSignInNonce {
    private static let box = Box()

    static func store(_ nonce: String) {
        box.store(nonce)
    }

    static func take() -> String? {
        box.take()
    }

    static func clear() {
        box.clear()
    }

    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var serverNonce: String?

        func store(_ nonce: String) {
            lock.lock()
            serverNonce = nonce
            lock.unlock()
        }

        func take() -> String? {
            lock.lock()
            defer { lock.unlock() }
            let nonce = serverNonce
            serverNonce = nil
            return nonce
        }

        func clear() {
            lock.lock()
            serverNonce = nil
            lock.unlock()
        }
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
