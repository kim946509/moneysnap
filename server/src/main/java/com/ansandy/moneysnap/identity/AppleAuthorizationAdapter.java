package com.ansandy.moneysnap.identity;

import java.util.Objects;

final class AppleAuthorizationAdapter implements AppleAuthorizationGateway {

	private final AppleIdentityVerifier identityVerifier;
	private final AppleTokenExchanger tokenExchanger;
	private final AppleRefreshTokenCipher refreshTokenCipher;

	AppleAuthorizationAdapter(
			AppleIdentityVerifier identityVerifier,
			AppleTokenExchanger tokenExchanger,
			AppleRefreshTokenCipher refreshTokenCipher) {
		this.identityVerifier = Objects.requireNonNull(identityVerifier);
		this.tokenExchanger = Objects.requireNonNull(tokenExchanger);
		this.refreshTokenCipher = Objects.requireNonNull(refreshTokenCipher);
	}

	@Override
	public VerifiedAppleAuthorization authorize(AppleAuthorizationRequest request) {
		Objects.requireNonNull(request);
		VerifiedAppleIdentity clientIdentity = identityVerifier.verify(
				request.identityToken(),
				request.nonce());
		AppleTokenExchange exchange = tokenExchanger.exchange(request.authorizationCode());
		VerifiedAppleIdentity exchangedIdentity = identityVerifier.verifyExchanged(
				exchange.identityToken(),
				request.nonce());
		if (!clientIdentity.subject().equals(exchangedIdentity.subject())) {
			throw new IdentitySessionException(IdentitySessionFailure.UNAUTHORIZED);
		}
		return new VerifiedAppleAuthorization(
				clientIdentity,
				refreshTokenCipher.encrypt(exchange.refreshToken()));
	}
}

@FunctionalInterface
interface AppleAuthorizationGateway {

	VerifiedAppleAuthorization authorize(AppleAuthorizationRequest request);
}

@FunctionalInterface
interface AppleIdentityVerifier {

	VerifiedAppleIdentity verify(String identityToken, String expectedNonce);

	default VerifiedAppleIdentity verifyExchanged(String identityToken, String expectedNonce) {
		return verify(identityToken, expectedNonce);
	}
}

@FunctionalInterface
interface AppleTokenExchanger {

	AppleTokenExchange exchange(String authorizationCode);
}

record AppleAuthorizationRequest(String identityToken, String authorizationCode, String nonce) {

	AppleAuthorizationRequest {
		requireText(identityToken);
		requireText(authorizationCode);
		requireText(nonce);
	}

	private static void requireText(String value) {
		if (value == null || value.isBlank()) {
			throw new IdentitySessionException(IdentitySessionFailure.UNAUTHORIZED);
		}
	}
}

record VerifiedAppleAuthorization(
		VerifiedAppleIdentity identity,
		String encryptedRefreshToken) {

	VerifiedAppleAuthorization {
		Objects.requireNonNull(identity);
		if (encryptedRefreshToken == null || encryptedRefreshToken.isBlank()) {
			throw new IdentitySessionException(IdentitySessionFailure.UNAUTHORIZED);
		}
	}
}
