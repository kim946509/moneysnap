package com.ansandy.moneysnap.identity;

import java.sql.Timestamp;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import org.springframework.beans.factory.ObjectProvider;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.support.TransactionTemplate;

import com.ansandy.moneysnap.shared.AccountMediaCleanup;
import com.ansandy.moneysnap.shared.SqliteColumns;

final class JdbcIdentitySessionStore implements IdentitySessionStore {

	private final JdbcClient jdbc;
	private final TransactionTemplate transactions;
	private final AccountMediaCleanup mediaCleanup;

	JdbcIdentitySessionStore(JdbcClient jdbc, TransactionTemplate transactions) {
		this(jdbc, transactions, null);
	}

	JdbcIdentitySessionStore(
			JdbcClient jdbc,
			TransactionTemplate transactions,
			ObjectProvider<AccountMediaCleanup> mediaCleanup) {
		this.jdbc = jdbc;
		this.transactions = transactions;
		this.mediaCleanup = mediaCleanup == null ? null : mediaCleanup.getIfAvailable();
	}

	@Override
	public UUID findOrCreateUser(String appleSubject, String encryptedAppleRefreshToken, Instant now) {
		return transactions.execute(status -> {
			Optional<UUID> existing = findUser(appleSubject);
			if (existing.isPresent()) {
				updateAppleRefreshToken(existing.get(), encryptedAppleRefreshToken, now);
				return existing.get();
			}

			UUID candidate = UUID.randomUUID();
			jdbc.sql("INSERT INTO users (id, created_at) VALUES (:id, :createdAt)")
					.param("id", candidate)
					.param("createdAt", SqliteColumns.instant(now))
					.update();
			int inserted = jdbc.sql("""
					INSERT INTO apple_identities (
						user_id, apple_subject, encrypted_apple_refresh_token, created_at, updated_at
					)
					VALUES (:userId, :subject, :encryptedRefreshToken, :now, :now)
					ON CONFLICT (apple_subject) DO NOTHING
					""")
					.param("userId", candidate)
					.param("subject", appleSubject)
					.param("encryptedRefreshToken", encryptedAppleRefreshToken)
					.param("now", SqliteColumns.instant(now))
					.update();
			if (inserted == 1) {
				return candidate;
			}

			UUID actual = findUser(appleSubject).orElseThrow();
			updateAppleRefreshToken(actual, encryptedAppleRefreshToken, now);
			jdbc.sql("DELETE FROM users WHERE id = :id")
					.param("id", candidate)
					.update();
			return actual;
		});
	}

	@Override
	public void createSession(NewIdentitySession session) {
		transactions.executeWithoutResult(status -> {
			jdbc.sql("""
					INSERT INTO identity_sessions (
						id, user_id, access_token_hash, access_expires_at,
						refresh_expires_at, created_at, last_used_at
					) VALUES (
						:id, :userId, :accessHash, :accessExpiresAt,
						:refreshExpiresAt, :createdAt, :createdAt
					)
					""")
					.param("id", session.sessionId())
					.param("userId", session.userId())
					.param("accessHash", session.accessTokenHash())
					.param("accessExpiresAt", SqliteColumns.instant(session.accessExpiresAt()))
					.param("refreshExpiresAt", SqliteColumns.instant(session.refreshExpiresAt()))
					.param("createdAt", SqliteColumns.instant(session.createdAt()))
					.update();
			insertRefreshToken(
					session.sessionId(),
					session.refreshTokenHash(),
					session.refreshExpiresAt(),
					session.createdAt());
		});
	}

	@Override
	public Optional<SessionActor> findActiveAccess(String accessTokenHash, Instant now) {
		return jdbc.sql("""
				SELECT user_id, id
				FROM identity_sessions
				WHERE access_token_hash = :accessHash
				  AND access_expires_at > :now
				  AND revoked_at IS NULL
				""")
				.param("accessHash", accessTokenHash)
				.param("now", SqliteColumns.instant(now))
				.query((row, rowNumber) -> new SessionActor(
						SqliteColumns.uuid(row, "user_id"),
						SqliteColumns.uuid(row, "id")))
				.optional();
	}

	@Override
	public RefreshRotation rotateRefresh(
			String currentRefreshTokenHash,
			String nextAccessTokenHash,
			Instant nextAccessExpiresAt,
			String nextRefreshTokenHash,
			Instant nextRefreshExpiresAt,
			Instant now) {
		return transactions.execute(status -> {
			Optional<RefreshRow> current = jdbc.sql("""
					SELECT r.id AS refresh_id, r.session_id, r.status, r.expires_at,
					       s.revoked_at
					FROM identity_refresh_tokens r
					JOIN identity_sessions s ON s.id = r.session_id
					WHERE r.token_hash = :tokenHash
					""")
					.param("tokenHash", currentRefreshTokenHash)
					.query((row, rowNumber) -> new RefreshRow(
							SqliteColumns.uuid(row, "refresh_id"),
							SqliteColumns.uuid(row, "session_id"),
							row.getString("status"),
							SqliteColumns.instant(row, "expires_at"),
							SqliteColumns.instant(row, "revoked_at")))
					.optional();

			if (current.isEmpty() || current.get().revokedAt() != null) {
				return RefreshRotation.INVALID;
			}
			RefreshRow token = current.get();
			if ("USED".equals(token.status())) {
				revokeSession(token.sessionId(), now);
				return RefreshRotation.REUSED;
			}
			if (!"ACTIVE".equals(token.status()) || !token.expiresAt().isAfter(now)) {
				return RefreshRotation.INVALID;
			}

			int claimed = jdbc.sql("""
					UPDATE identity_refresh_tokens
					SET status = 'USED', used_at = :now
					WHERE id = :id AND status = 'ACTIVE'
					""")
					.param("id", token.refreshId())
					.param("now", SqliteColumns.instant(now))
					.update();
			if (claimed != 1) {
				revokeSession(token.sessionId(), now);
				return RefreshRotation.REUSED;
			}
			jdbc.sql("""
					UPDATE identity_sessions
					SET access_token_hash = :accessHash,
					    access_expires_at = :accessExpiresAt,
					    refresh_expires_at = :refreshExpiresAt,
					    last_used_at = :now
					WHERE id = :sessionId AND revoked_at IS NULL
					""")
					.param("sessionId", token.sessionId())
					.param("accessHash", nextAccessTokenHash)
					.param("accessExpiresAt", SqliteColumns.instant(nextAccessExpiresAt))
					.param("refreshExpiresAt", SqliteColumns.instant(nextRefreshExpiresAt))
					.param("now", SqliteColumns.instant(now))
					.update();
			insertRefreshToken(token.sessionId(), nextRefreshTokenHash, nextRefreshExpiresAt, now);
			return RefreshRotation.SUCCESS;
		});
	}

	@Override
	public void revokeSession(UUID sessionId, Instant now) {
		jdbc.sql("""
				UPDATE identity_sessions
				SET revoked_at = COALESCE(revoked_at, :now)
				WHERE id = :sessionId
				""")
				.param("sessionId", sessionId)
				.param("now", SqliteColumns.instant(now))
				.update();
	}

	@Override
	public boolean isIdentityOwnedBy(UUID userId, String appleSubject) {
		return jdbc.sql("""
				SELECT count(*)
				FROM apple_identities
				WHERE user_id = :userId AND apple_subject = :appleSubject
				""")
				.param("userId", userId)
				.param("appleSubject", appleSubject)
				.query(Integer.class)
				.single() == 1;
	}

	@Override
	public void deleteUser(UUID userId) {
		if (mediaCleanup != null) {
			mediaCleanup.transferToTombstones(userId);
		}
		jdbc.sql("DELETE FROM users WHERE id = :userId")
				.param("userId", userId)
				.update();
	}

	@Override
	public void applyAppleAccountEvent(VerifiedAppleAccountEvent event, Instant receivedAt) {
		transactions.executeWithoutResult(status -> {
			int inserted = jdbc.sql("""
					INSERT INTO apple_account_event_receipts (event_id, received_at)
					VALUES (:eventId, :receivedAt)
					ON CONFLICT (event_id) DO NOTHING
					""")
					.param("eventId", event.eventId())
					.param("receivedAt", SqliteColumns.instant(receivedAt))
					.update();
			if (inserted == 0) {
				return;
			}

			switch (event.type()) {
				case CONSENT_REVOKED -> revokeAllSessions(event.subject(), receivedAt);
				case ACCOUNT_DELETED -> deleteUser(event.subject());
				case EMAIL_ENABLED, EMAIL_DISABLED -> {
				}
			}
		});
	}

	private void revokeAllSessions(String appleSubject, Instant now) {
		jdbc.sql("""
				UPDATE identity_sessions
				SET revoked_at = COALESCE(revoked_at, :now)
				WHERE user_id = (
					SELECT user_id FROM apple_identities WHERE apple_subject = :appleSubject
				)
				""")
				.param("appleSubject", appleSubject)
				.param("now", SqliteColumns.instant(now))
				.update();
	}

	private void deleteUser(String appleSubject) {
		jdbc.sql("""
				DELETE FROM users
				WHERE id = (
					SELECT user_id FROM apple_identities WHERE apple_subject = :appleSubject
				)
				""")
				.param("appleSubject", appleSubject)
				.update();
	}

	private Optional<UUID> findUser(String appleSubject) {
		return jdbc.sql("SELECT user_id FROM apple_identities WHERE apple_subject = :subject")
				.param("subject", appleSubject)
				.query(SqliteColumns::firstUuid)
				.optional();
	}

	private void updateAppleRefreshToken(UUID userId, String encryptedAppleRefreshToken, Instant now) {
		if (encryptedAppleRefreshToken == null) {
			return;
		}
		jdbc.sql("""
				UPDATE apple_identities
				SET encrypted_apple_refresh_token = :encryptedRefreshToken,
				    updated_at = :now
				WHERE user_id = :userId
				""")
				.param("userId", userId)
				.param("encryptedRefreshToken", encryptedAppleRefreshToken)
				.param("now", SqliteColumns.instant(now))
				.update();
	}

	private void insertRefreshToken(UUID sessionId, String tokenHash, Instant expiresAt, Instant now) {
		jdbc.sql("""
				INSERT INTO identity_refresh_tokens (
					id, session_id, token_hash, status, expires_at, created_at
				) VALUES (:id, :sessionId, :tokenHash, 'ACTIVE', :expiresAt, :createdAt)
				""")
				.param("id", UUID.randomUUID())
				.param("sessionId", sessionId)
				.param("tokenHash", tokenHash)
				.param("expiresAt", SqliteColumns.instant(expiresAt))
				.param("createdAt", SqliteColumns.instant(now))
				.update();
	}

	private record RefreshRow(
			UUID refreshId,
			UUID sessionId,
			String status,
			Instant expiresAt,
			Instant revokedAt) {
	}
}
