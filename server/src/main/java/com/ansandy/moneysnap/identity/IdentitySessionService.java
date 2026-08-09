package com.ansandy.moneysnap.identity;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

final class IdentitySessionService {

	private static final Duration ACCESS_LIFETIME = Duration.ofMinutes(15);
	private static final Duration REFRESH_INACTIVITY_LIFETIME = Duration.ofDays(180);

	private final IdentitySessionStore store;
	private final SessionTokenGenerator tokenGenerator;
	private final Sha256TokenHasher tokenHasher;
	private final Clock clock;

	IdentitySessionService(
			IdentitySessionStore store,
			SessionTokenGenerator tokenGenerator,
			Sha256TokenHasher tokenHasher,
			Clock clock) {
		this.store = Objects.requireNonNull(store);
		this.tokenGenerator = Objects.requireNonNull(tokenGenerator);
		this.tokenHasher = Objects.requireNonNull(tokenHasher);
		this.clock = Objects.requireNonNull(clock);
	}

	SessionTokens signIn(VerifiedAppleIdentity identity) {
		Objects.requireNonNull(identity);
		Instant now = clock.instant();
		UUID userId = store.findOrCreateUser(identity.subject(), now);
		SessionTokens issued = issueTokens(now);
		store.createSession(new NewIdentitySession(
				UUID.randomUUID(),
				userId,
				tokenHasher.hash(issued.accessToken()),
				issued.accessExpiresAt(),
				tokenHasher.hash(issued.refreshToken()),
				issued.refreshExpiresAt(),
				now));
		return issued;
	}

	SessionActor authenticate(String accessToken) {
		String hash = tokenHasher.hash(requireToken(accessToken));
		return store.findActiveAccess(hash, clock.instant())
				.orElseThrow(() -> new IdentitySessionException(IdentitySessionFailure.UNAUTHORIZED));
	}

	SessionTokens refresh(String refreshToken) {
		String currentHash = tokenHasher.hash(requireToken(refreshToken));
		Instant now = clock.instant();
		SessionTokens issued = issueTokens(now);
		RefreshRotation rotation = store.rotateRefresh(
				currentHash,
				tokenHasher.hash(issued.accessToken()),
				issued.accessExpiresAt(),
				tokenHasher.hash(issued.refreshToken()),
				issued.refreshExpiresAt(),
				now);

		if (rotation == RefreshRotation.SUCCESS) {
			return issued;
		}
		if (rotation == RefreshRotation.REUSED) {
			throw new IdentitySessionException(IdentitySessionFailure.REFRESH_TOKEN_REUSED);
		}
		throw new IdentitySessionException(IdentitySessionFailure.UNAUTHORIZED);
	}

	void logout(String accessToken) {
		store.revokeSession(authenticate(accessToken).sessionId(), clock.instant());
	}

	private SessionTokens issueTokens(Instant now) {
		String accessToken = requireToken(tokenGenerator.generate());
		String refreshToken = requireToken(tokenGenerator.generate());
		if (accessToken.equals(refreshToken)) {
			throw new IllegalStateException("Token generator returned duplicate values");
		}
		return new SessionTokens(
				accessToken,
				now.plus(ACCESS_LIFETIME),
				refreshToken,
				now.plus(REFRESH_INACTIVITY_LIFETIME));
	}

	private static String requireToken(String token) {
		if (token == null || token.isBlank()) {
			throw new IdentitySessionException(IdentitySessionFailure.UNAUTHORIZED);
		}
		return token;
	}

}

record VerifiedAppleIdentity(String subject) {

	VerifiedAppleIdentity {
		if (subject == null || subject.isBlank() || subject.length() > 255) {
			throw new IllegalArgumentException("Apple subject must be 1 to 255 characters");
		}
	}
}

record SessionTokens(
		String accessToken,
		Instant accessExpiresAt,
		String refreshToken,
		Instant refreshExpiresAt) {
}

record SessionActor(UUID userId, UUID sessionId) {
}

record NewIdentitySession(
		UUID sessionId,
		UUID userId,
		String accessTokenHash,
		Instant accessExpiresAt,
		String refreshTokenHash,
		Instant refreshExpiresAt,
		Instant createdAt) {
}

enum RefreshRotation {
	SUCCESS,
	REUSED,
	INVALID
}

enum IdentitySessionFailure {
	UNAUTHORIZED,
	REFRESH_TOKEN_REUSED
}

final class IdentitySessionException extends RuntimeException {

	private final IdentitySessionFailure failure;

	IdentitySessionException(IdentitySessionFailure failure) {
		super(failure.name());
		this.failure = failure;
	}

	IdentitySessionFailure failure() {
		return failure;
	}
}

interface IdentitySessionStore {

	UUID findOrCreateUser(String appleSubject, Instant now);

	void createSession(NewIdentitySession session);

	Optional<SessionActor> findActiveAccess(String accessTokenHash, Instant now);

	RefreshRotation rotateRefresh(
			String currentRefreshTokenHash,
			String nextAccessTokenHash,
			Instant nextAccessExpiresAt,
			String nextRefreshTokenHash,
			Instant nextRefreshExpiresAt,
			Instant now);

	void revokeSession(UUID sessionId, Instant now);
}

interface SessionTokenGenerator {

	String generate();
}
