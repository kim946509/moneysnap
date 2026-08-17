package com.ansandy.moneysnap.identity;

import java.util.Objects;
import java.util.UUID;

final class AccountDeletionService {

	private final IdentitySessionStore store;
	private final AppleRefreshTokenCipher refreshTokenCipher;
	private final AppleTokenRevoker apple;

	AccountDeletionService(
			IdentitySessionStore store,
			AppleRefreshTokenCipher refreshTokenCipher,
			AppleTokenRevoker apple) {
		this.store = Objects.requireNonNull(store);
		this.refreshTokenCipher = Objects.requireNonNull(refreshTokenCipher);
		this.apple = Objects.requireNonNull(apple);
	}

	void delete(UUID userId, VerifiedAppleAuthorization reauthorization) {
		Objects.requireNonNull(userId);
		Objects.requireNonNull(reauthorization);
		if (!store.isIdentityOwnedBy(userId, reauthorization.identity().subject())) {
			throw new IdentitySessionException(IdentitySessionFailure.UNAUTHORIZED);
		}
		String refreshToken = refreshTokenCipher.decrypt(reauthorization.encryptedRefreshToken());
		apple.revoke(refreshToken);
		store.deleteUser(userId);
	}
}
