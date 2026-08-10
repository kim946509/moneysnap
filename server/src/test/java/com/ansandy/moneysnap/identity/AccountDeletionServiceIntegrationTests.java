package com.ansandy.moneysnap.identity;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayDeque;
import java.util.Base64;
import java.util.Queue;

import javax.sql.DataSource;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
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
class AccountDeletionServiceIntegrationTests {

	private static final Instant NOW = Instant.parse("2026-08-10T13:00:00Z");

	@Container
	private static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(
			DockerImageName.parse("postgres:18-alpine"));

	private static JdbcClient jdbc;
	private IdentitySessionService sessions;
	private JdbcIdentitySessionStore store;
	private AppleRefreshTokenCipher cipher;
	private RecordingAppleTokenRevoker apple;

	@BeforeAll
	static void migrateDatabase() {
		DataSource dataSource = dataSource();
		Flyway.configure().dataSource(dataSource).load().migrate();
		jdbc = JdbcClient.create(dataSource);
	}

	@BeforeEach
	void setUp() {
		jdbc.sql("TRUNCATE TABLE identity_refresh_tokens, identity_sessions, apple_identities, users CASCADE")
				.update();
		DataSource dataSource = dataSource();
		store = new JdbcIdentitySessionStore(
				JdbcClient.create(dataSource),
				new TransactionTemplate(new DataSourceTransactionManager(dataSource)));
		sessions = new IdentitySessionService(
				store,
				new QueueTokenGenerator(
						"access-a", "refresh-a", "access-b", "refresh-b",
						"access-c", "refresh-c", "access-d", "refresh-d"),
				new Sha256TokenHasher(),
				Clock.fixed(NOW, ZoneOffset.UTC));
		cipher = new AppleRefreshTokenCipher(Base64.getEncoder().encodeToString(new byte[32]));
		apple = new RecordingAppleTokenRevoker();
	}

	@Test
	void deletesTheUserAndEveryDeviceSession() {
		SessionTokens firstDevice = sessions.signIn(new VerifiedAppleIdentity("apple-delete-subject"));
		sessions.signIn(new VerifiedAppleIdentity("apple-delete-subject"));
		SessionActor actor = sessions.authenticate(firstDevice.accessToken());
		AccountDeletionService deletion = new AccountDeletionService(store, cipher, apple);

		deletion.delete(actor, new VerifiedAppleAuthorization(
				new VerifiedAppleIdentity("apple-delete-subject"),
				cipher.encrypt("reauth-apple-refresh-token")));

		assertThat(rowCount("users")).isZero();
		assertThat(rowCount("apple_identities")).isZero();
		assertThat(rowCount("identity_sessions")).isZero();
		assertThat(rowCount("identity_refresh_tokens")).isZero();
	}

	@Test
	void revokesTheRefreshTokenFromAppleReauthentication() {
		SessionTokens tokens = sessions.signIn(new VerifiedAppleIdentity("apple-delete-subject"));
		SessionActor actor = sessions.authenticate(tokens.accessToken());

		deletion().delete(actor, reauthorization("apple-delete-subject"));

		assertThat(apple.revokedRefreshToken).isEqualTo("reauth-apple-refresh-token");
	}

	@Test
	void rejectsAReauthenticatedDifferentAppleUserWithoutSideEffects() {
		SessionTokens tokens = sessions.signIn(new VerifiedAppleIdentity("current-apple-subject"));
		SessionActor actor = sessions.authenticate(tokens.accessToken());

		assertThatThrownBy(() -> deletion().delete(actor, reauthorization("different-apple-subject")))
				.isInstanceOf(IdentitySessionException.class)
				.extracting(error -> ((IdentitySessionException) error).failure())
				.isEqualTo(IdentitySessionFailure.UNAUTHORIZED);
		assertThat(apple.revokedRefreshToken).isNull();
		assertThat(rowCount("users")).isOne();
	}

	@Test
	void preservesTheAccountAndSessionsWhenAppleRevocationFails() {
		SessionTokens firstDevice = sessions.signIn(new VerifiedAppleIdentity("apple-delete-subject"));
		sessions.signIn(new VerifiedAppleIdentity("apple-delete-subject"));
		SessionActor actor = sessions.authenticate(firstDevice.accessToken());
		apple.fail = true;

		assertThatThrownBy(() -> deletion().delete(actor, reauthorization("apple-delete-subject")))
				.isInstanceOf(AppleRevocationException.class);
		assertThat(rowCount("users")).isOne();
		assertThat(rowCount("identity_sessions")).isEqualTo(2);
	}

	@Test
	void rejectsEveryMoneySnapTokenAfterDeletion() {
		SessionTokens firstDevice = sessions.signIn(new VerifiedAppleIdentity("apple-delete-subject"));
		SessionTokens secondDevice = sessions.signIn(new VerifiedAppleIdentity("apple-delete-subject"));
		SessionActor actor = sessions.authenticate(firstDevice.accessToken());

		deletion().delete(actor, reauthorization("apple-delete-subject"));

		assertUnauthorized(() -> sessions.authenticate(firstDevice.accessToken()));
		assertUnauthorized(() -> sessions.refresh(firstDevice.refreshToken()));
		assertUnauthorized(() -> sessions.authenticate(secondDevice.accessToken()));
		assertUnauthorized(() -> sessions.refresh(secondDevice.refreshToken()));
	}

	private AccountDeletionService deletion() {
		return new AccountDeletionService(store, cipher, apple);
	}

	private VerifiedAppleAuthorization reauthorization(String subject) {
		return new VerifiedAppleAuthorization(
				new VerifiedAppleIdentity(subject),
				cipher.encrypt("reauth-apple-refresh-token"));
	}

	private static void assertUnauthorized(ThrowingCall call) {
		assertThatThrownBy(call::run)
				.isInstanceOf(IdentitySessionException.class)
				.extracting(error -> ((IdentitySessionException) error).failure())
				.isEqualTo(IdentitySessionFailure.UNAUTHORIZED);
	}

	private static int rowCount(String table) {
		return jdbc.sql("SELECT count(*) FROM " + table)
				.query(Integer.class)
				.single();
	}

	private static DataSource dataSource() {
		return new DriverManagerDataSource(
				POSTGRES.getJdbcUrl(),
				POSTGRES.getUsername(),
				POSTGRES.getPassword());
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

	private static final class RecordingAppleTokenRevoker implements AppleTokenRevoker {

		private String revokedRefreshToken;
		private boolean fail;

		@Override
		public void revoke(String refreshToken) {
			revokedRefreshToken = refreshToken;
			if (fail) {
				throw new AppleRevocationException();
			}
		}
	}

	@FunctionalInterface
	private interface ThrowingCall {

		void run();
	}
}
