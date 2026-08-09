package com.ansandy.moneysnap.identity;

import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayDeque;
import java.util.List;
import java.util.Queue;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import javax.sql.DataSource;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.transaction.support.TransactionTemplate;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

@Testcontainers
class IdentitySessionServiceIntegrationTests {

	private static final Instant NOW = Instant.parse("2026-08-09T04:00:00Z");

	@Container
	private static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(
			DockerImageName.parse("postgres:18-alpine"));

	private static JdbcClient jdbcClient;
	private IdentitySessionService sessions;
	private JdbcIdentitySessionStore store;

	@BeforeAll
	static void migrateDatabase() {
		DataSource dataSource = dataSource();
		Flyway.configure().dataSource(dataSource).load().migrate();
		jdbcClient = JdbcClient.create(dataSource);
	}

	@BeforeEach
	void resetDatabase() {
		jdbcClient.sql("TRUNCATE TABLE identity_refresh_tokens, identity_sessions, apple_identities, users CASCADE")
				.update();
		QueueTokenGenerator tokens = new QueueTokenGenerator(
				"access-a", "refresh-a", "access-b", "refresh-b",
				"access-c", "refresh-c", "access-d", "refresh-d");
		DataSource dataSource = dataSource();
		store = new JdbcIdentitySessionStore(
				JdbcClient.create(dataSource),
				new TransactionTemplate(new DataSourceTransactionManager(dataSource)));
		sessions = new IdentitySessionService(store, tokens, new Sha256TokenHasher(), fixedClock(NOW));
	}

	@Test
	void signsInTheSameAppleSubjectAsTheSameUser() {
		SessionTokens first = sessions.signIn(new VerifiedAppleIdentity("apple-subject-1"));
		SessionActor firstActor = sessions.authenticate(first.accessToken());
		SessionTokens second = sessions.signIn(new VerifiedAppleIdentity("apple-subject-1"));
		SessionActor secondActor = sessions.authenticate(second.accessToken());

		assertThat(firstActor.userId()).isEqualTo(secondActor.userId());
	}

	@Test
	void signInUsesTheConfiguredSessionLifetimes() {
		SessionTokens tokens = sessions.signIn(new VerifiedAppleIdentity("apple-subject-ttl"));

		assertThat(tokens.accessExpiresAt()).isEqualTo(NOW.plus(Duration.ofMinutes(15)));
		assertThat(tokens.refreshExpiresAt()).isEqualTo(NOW.plus(Duration.ofDays(180)));
	}

	@Test
	void accessTokenIsRejectedAtTheFifteenMinuteBoundary() {
		SessionTokens tokens = sessions.signIn(new VerifiedAppleIdentity("apple-subject-access-expiry"));

		assertUnauthorized(() -> sessionsAt(NOW.plus(Duration.ofMinutes(15)))
				.authenticate(tokens.accessToken()));
	}

	@Test
	void refreshTokenIsRejectedAtTheOneHundredEightyDayBoundary() {
		SessionTokens tokens = sessions.signIn(new VerifiedAppleIdentity("apple-subject-refresh-expiry"));

		assertUnauthorized(() -> sessionsAt(NOW.plus(Duration.ofDays(180)))
				.refresh(tokens.refreshToken()));
	}

	@Test
	void persistenceStoresOnlyTokenHashes() {
		SessionTokens tokens = sessions.signIn(new VerifiedAppleIdentity("apple-subject-hash"));

		assertThat(storedValueCount("identity_sessions", "access_token_hash", tokens.accessToken())).isZero();
		assertThat(storedValueCount("identity_refresh_tokens", "token_hash", tokens.refreshToken())).isZero();
	}

	@Test
	void databaseRejectsMoreThanOneActiveRefreshTokenPerSession() {
		SessionTokens tokens = sessions.signIn(new VerifiedAppleIdentity("apple-subject-active-refresh"));
		UUID sessionId = sessions.authenticate(tokens.accessToken()).sessionId();

		assertThatThrownBy(() -> jdbcClient.sql("""
				INSERT INTO identity_refresh_tokens (
					id, session_id, token_hash, status, expires_at, created_at
				) VALUES (
					:id, :sessionId, :tokenHash, 'ACTIVE', :expiresAt, :createdAt
				)
				""")
				.param("id", UUID.randomUUID())
				.param("sessionId", sessionId)
				.param("tokenHash", new Sha256TokenHasher().hash("second-active-refresh"))
				.param("expiresAt", Timestamp.from(NOW.plus(Duration.ofDays(180))))
				.param("createdAt", Timestamp.from(NOW))
				.update())
				.isInstanceOf(DataIntegrityViolationException.class);
	}

	@Test
	void refreshRotatesBothTokensAndRejectsThePreviousAccessToken() {
		SessionTokens initial = sessions.signIn(new VerifiedAppleIdentity("apple-subject-2"));

		SessionTokens rotated = sessions.refresh(initial.refreshToken());

		assertUnauthorized(() -> sessions.authenticate(initial.accessToken()));
		assertThat(sessions.authenticate(rotated.accessToken()).userId()).isNotNull();
		assertThat(rotated.accessExpiresAt()).isEqualTo(NOW.plus(Duration.ofMinutes(15)));
		assertThat(rotated.refreshExpiresAt()).isEqualTo(NOW.plus(Duration.ofDays(180)));
	}

	@Test
	void refreshExtendsTheInactivityWindowFromTheTimeOfUse() {
		SessionTokens initial = sessions.signIn(new VerifiedAppleIdentity("apple-subject-inactivity"));
		Instant refreshedAt = NOW.plus(Duration.ofDays(30));

		SessionTokens rotated = sessionsAt(refreshedAt).refresh(initial.refreshToken());

		assertThat(rotated.refreshExpiresAt()).isEqualTo(refreshedAt.plus(Duration.ofDays(180)));
	}

	@Test
	void failedRefreshRotationRollsBackTheCurrentSession() {
		IdentitySessionService rollbackSessions = new IdentitySessionService(
				store,
				new QueueTokenGenerator(
						"access-original", "refresh-original",
						"access-collision", "refresh-original",
						"access-final", "refresh-final"),
				new Sha256TokenHasher(),
				fixedClock(NOW));
		SessionTokens initial = rollbackSessions.signIn(new VerifiedAppleIdentity("apple-subject-rollback"));

		assertThatThrownBy(() -> rollbackSessions.refresh(initial.refreshToken()))
				.isInstanceOf(DataIntegrityViolationException.class);
		assertThat(rollbackSessions.authenticate(initial.accessToken()).userId()).isNotNull();

		SessionTokens rotated = rollbackSessions.refresh(initial.refreshToken());
		assertThat(rollbackSessions.authenticate(rotated.accessToken()).userId()).isNotNull();
	}

	@Test
	void reusingARefreshTokenRevokesTheWholeSessionFamily() {
		SessionTokens initial = sessions.signIn(new VerifiedAppleIdentity("apple-subject-3"));
		SessionTokens rotated = sessions.refresh(initial.refreshToken());

		assertThatThrownBy(() -> sessions.refresh(initial.refreshToken()))
				.isInstanceOf(IdentitySessionException.class)
				.extracting(error -> ((IdentitySessionException) error).failure())
				.isEqualTo(IdentitySessionFailure.REFRESH_TOKEN_REUSED);
		assertUnauthorized(() -> sessions.authenticate(rotated.accessToken()));
		assertThatThrownBy(() -> sessions.refresh(rotated.refreshToken()))
				.isInstanceOf(IdentitySessionException.class);
	}

	@Test
	void concurrentRefreshReuseRevokesTheWholeSessionFamily() throws Exception {
		IdentitySessionService concurrentSessions = sessionsAt(NOW);
		SessionTokens initial = concurrentSessions.signIn(new VerifiedAppleIdentity("apple-subject-concurrent"));
		CountDownLatch start = new CountDownLatch(1);
		Callable<Object> refresh = () -> {
			start.await();
			try {
				return concurrentSessions.refresh(initial.refreshToken());
			}
			catch (IdentitySessionException exception) {
				return exception.failure();
			}
		};

		ExecutorService executor = Executors.newFixedThreadPool(2);
		List<Object> results;
		try {
			Future<Object> first = executor.submit(refresh);
			Future<Object> second = executor.submit(refresh);
			start.countDown();
			results = List.of(first.get(5, TimeUnit.SECONDS), second.get(5, TimeUnit.SECONDS));
		}
		finally {
			executor.shutdownNow();
		}

		assertThat(results).filteredOn(SessionTokens.class::isInstance).hasSize(1);
		assertThat(results).contains(IdentitySessionFailure.REFRESH_TOKEN_REUSED);
		SessionTokens rotated = (SessionTokens) results.stream()
				.filter(SessionTokens.class::isInstance)
				.findFirst()
				.orElseThrow();
		assertUnauthorized(() -> concurrentSessions.authenticate(rotated.accessToken()));
	}

	@Test
	void logoutRevokesAccessAndRefreshTokens() {
		SessionTokens tokens = sessions.signIn(new VerifiedAppleIdentity("apple-subject-4"));

		sessions.logout(tokens.accessToken());

		assertUnauthorized(() -> sessions.authenticate(tokens.accessToken()));
		assertThatThrownBy(() -> sessions.refresh(tokens.refreshToken()))
				.isInstanceOf(IdentitySessionException.class);
	}

	@Test
	void logoutRevokesTheSessionWhenTheAccessTokenRotatesConcurrently() throws Exception {
		SessionTokens tokens = sessions.signIn(new VerifiedAppleIdentity("apple-subject-race"));
		UUID sessionId = sessions.authenticate(tokens.accessToken()).sessionId();
		String rotatedAccessToken = "access-raced";

		ExecutorService executor = Executors.newSingleThreadExecutor();
		try (var lockConnection = dataSource().getConnection();
				var rotateAccess = lockConnection.prepareStatement("""
						UPDATE identity_sessions
						SET access_token_hash = ?
						WHERE id = ?
						""")) {
			lockConnection.setAutoCommit(false);
			rotateAccess.setString(1, new Sha256TokenHasher().hash(rotatedAccessToken));
			rotateAccess.setObject(2, sessionId);
			rotateAccess.executeUpdate();

			Future<?> logout = executor.submit(() -> sessions.logout(tokens.accessToken()));
			waitForBlockedSessionUpdate();
			lockConnection.commit();
			logout.get(5, TimeUnit.SECONDS);
		}
		finally {
			executor.shutdownNow();
		}

		assertUnauthorized(() -> sessions.authenticate(rotatedAccessToken));
		assertThatThrownBy(() -> sessions.refresh(tokens.refreshToken()))
				.isInstanceOf(IdentitySessionException.class);
	}

	private static DataSource dataSource() {
		DriverManagerDataSource dataSource = new DriverManagerDataSource();
		dataSource.setDriverClassName("org.postgresql.Driver");
		dataSource.setUrl(POSTGRES.getJdbcUrl());
		dataSource.setUsername(POSTGRES.getUsername());
		dataSource.setPassword(POSTGRES.getPassword());
		return dataSource;
	}

	private static Clock fixedClock(Instant instant) {
		return Clock.fixed(instant, ZoneOffset.UTC);
	}

	private IdentitySessionService sessionsAt(Instant instant) {
		return new IdentitySessionService(
				store,
				new SecureSessionTokenGenerator(),
				new Sha256TokenHasher(),
				fixedClock(instant));
	}

	private int storedValueCount(String table, String column, String rawToken) {
		return jdbcClient.sql("SELECT count(*) FROM " + table + " WHERE " + column + " = :rawToken")
				.param("rawToken", rawToken)
				.query(Integer.class)
				.single();
	}

	private void waitForBlockedSessionUpdate() throws InterruptedException {
		long deadline = System.nanoTime() + TimeUnit.SECONDS.toNanos(5);
		while (System.nanoTime() < deadline) {
			int blocked = jdbcClient.sql("""
					SELECT count(*)
					FROM pg_stat_activity
					WHERE datname = current_database()
					  AND wait_event_type = 'Lock'
					  AND query ILIKE '%UPDATE identity_sessions%'
					""")
					.query(Integer.class)
					.single();
			if (blocked > 0) {
				return;
			}
			Thread.sleep(10);
		}
		throw new AssertionError("Logout did not block on the concurrent session update");
	}

	private static void assertUnauthorized(ThrowingCall call) {
		assertThatThrownBy(call::run)
				.isInstanceOf(IdentitySessionException.class)
				.extracting(error -> ((IdentitySessionException) error).failure())
				.isEqualTo(IdentitySessionFailure.UNAUTHORIZED);
	}

	@FunctionalInterface
	private interface ThrowingCall {
		void run();
	}

	private static final class QueueTokenGenerator implements SessionTokenGenerator {
		private final Queue<String> values;

		private QueueTokenGenerator(String... values) {
			this.values = new ArrayDeque<>(java.util.List.of(values));
		}

		@Override
		public String generate() {
			return values.remove();
		}
	}
}
