package com.ansandy.moneysnap.identity;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.ArrayDeque;
import java.util.List;
import java.util.Queue;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import javax.sql.DataSource;

import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.transaction.support.TransactionTemplate;
import com.ansandy.moneysnap.SqliteTestDatabase;

import static org.assertj.core.api.Assertions.assertThat;

class AppleAccountEventServiceIntegrationTests {

	private static final Instant NOW = Instant.parse("2026-08-10T14:00:00Z");
	private static final String SQLITE_URL = SqliteTestDatabase.fileUrl();


	private static JdbcClient jdbc;
	private IdentitySessionService sessions;
	private AppleAccountEventService events;

	@BeforeAll
	static void migrateDatabase() {
		DataSource dataSource = dataSource();
		Flyway.configure().dataSource(dataSource).load().migrate();
		jdbc = JdbcClient.create(dataSource);
	}

	@BeforeEach
	void setUp() {
		SqliteTestDatabase.clear(jdbc);
		DataSource dataSource = dataSource();
		JdbcIdentitySessionStore store = new JdbcIdentitySessionStore(
				JdbcClient.create(dataSource),
				new TransactionTemplate(new DataSourceTransactionManager(dataSource)));
		sessions = new IdentitySessionService(
				store,
				new QueueTokenGenerator(
						"access-a", "refresh-a", "access-b", "refresh-b",
						"access-c", "refresh-c", "access-d", "refresh-d"),
				new Sha256TokenHasher(),
				fixedClock());
		events = new AppleAccountEventService(store, fixedClock());
	}

	@Test
	void consentRevokedRejectsEverySessionForTheAppleIdentity() {
		SessionTokens first = sessions.signIn(new VerifiedAppleIdentity("apple-event-subject"));
		SessionTokens second = sessions.signIn(new VerifiedAppleIdentity("apple-event-subject"));

		events.handle(event("event-consent", AppleAccountEventType.CONSENT_REVOKED));

		assertThat(List.of(
				isUnauthorized(() -> sessions.authenticate(first.accessToken())),
				isUnauthorized(() -> sessions.refresh(first.refreshToken())),
				isUnauthorized(() -> sessions.authenticate(second.accessToken())),
				isUnauthorized(() -> sessions.refresh(second.refreshToken()))))
				.containsOnly(true);
	}

	@Test
	void consentRevokedPreservesTheUserData() {
		sessions.signIn(new VerifiedAppleIdentity("apple-event-subject"));

		events.handle(event("event-consent", AppleAccountEventType.CONSENT_REVOKED));

		assertThat(userCount()).isOne();
	}

	@Test
	void accountDeletedRemovesTheUserAndAllSessionData() {
		sessions.signIn(new VerifiedAppleIdentity("apple-event-subject"));
		sessions.signIn(new VerifiedAppleIdentity("apple-event-subject"));

		events.handle(event("event-delete", AppleAccountEventType.ACCOUNT_DELETED));

		assertThat(List.of(
				userCount(),
				appleIdentityCount(),
				sessionCount(),
				refreshTokenCount()))
				.containsOnly(0);
	}

	@Test
	void replayDoesNotRevokeASessionCreatedAfterTheFirstDelivery() {
		sessions.signIn(new VerifiedAppleIdentity("apple-event-subject"));
		VerifiedAppleAccountEvent event = event("event-consent", AppleAccountEventType.CONSENT_REVOKED);
		events.handle(event);
		SessionTokens signedInAfterEvent = sessions.signIn(new VerifiedAppleIdentity("apple-event-subject"));

		events.handle(event);

		assertThat(sessions.authenticate(signedInAfterEvent.accessToken()).userId()).isNotNull();
	}

	@ParameterizedTest
	@EnumSource(value = AppleAccountEventType.class, names = {"EMAIL_ENABLED", "EMAIL_DISABLED"})
	void emailEventsDoNotChangeCurrentProductData(AppleAccountEventType type) {
		SessionTokens tokens = sessions.signIn(new VerifiedAppleIdentity("apple-event-subject"));

		events.handle(event("event-email", type));

		assertThat(sessions.authenticate(tokens.accessToken()).userId()).isNotNull();
	}

	@Test
	void recordsAnEventForAnUnknownLocalAppleIdentity() {
		events.handle(event("event-missing-user", AppleAccountEventType.ACCOUNT_DELETED));

		assertThat(receiptCount()).isOne();
	}

	@Test
	void concurrentRedeliveryCreatesOneReceipt() throws Exception {
		VerifiedAppleAccountEvent event = event("event-concurrent", AppleAccountEventType.EMAIL_DISABLED);
		CountDownLatch start = new CountDownLatch(1);
		ExecutorService executor = Executors.newFixedThreadPool(2);
		try {
			Future<?> first = executor.submit(() -> handleAfter(start, event));
			Future<?> second = executor.submit(() -> handleAfter(start, event));
			start.countDown();
			first.get(5, TimeUnit.SECONDS);
			second.get(5, TimeUnit.SECONDS);
		}
		finally {
			executor.shutdownNow();
		}

		assertThat(receiptCount()).isOne();
	}

	private static VerifiedAppleAccountEvent event(String id, AppleAccountEventType type) {
		return new VerifiedAppleAccountEvent(id, type, "apple-event-subject", NOW.minusSeconds(5));
	}

	private static boolean isUnauthorized(ThrowingCall call) {
		try {
			call.run();
			return false;
		}
		catch (IdentitySessionException exception) {
			return exception.failure() == IdentitySessionFailure.UNAUTHORIZED;
		}
	}

	private void handleAfter(CountDownLatch start, VerifiedAppleAccountEvent event) {
		try {
			start.await();
			events.handle(event);
		}
		catch (InterruptedException exception) {
			Thread.currentThread().interrupt();
			throw new AssertionError(exception);
		}
	}

	private static int userCount() {
		return jdbc.sql("SELECT count(*) FROM users").query(Integer.class).single();
	}

	private static int appleIdentityCount() {
		return jdbc.sql("SELECT count(*) FROM apple_identities").query(Integer.class).single();
	}

	private static int sessionCount() {
		return jdbc.sql("SELECT count(*) FROM identity_sessions").query(Integer.class).single();
	}

	private static int refreshTokenCount() {
		return jdbc.sql("SELECT count(*) FROM identity_refresh_tokens").query(Integer.class).single();
	}

	private static int receiptCount() {
		return jdbc.sql("SELECT count(*) FROM apple_account_event_receipts").query(Integer.class).single();
	}

	private static DataSource dataSource() {
		return SqliteTestDatabase.dataSource(SQLITE_URL);
	}

	private static Clock fixedClock() {
		return Clock.fixed(NOW, ZoneOffset.UTC);
	}

	private static final class QueueTokenGenerator implements SessionTokenGenerator {

		private final Queue<String> values;

		private QueueTokenGenerator(String... values) {
			this.values = new ArrayDeque<>(List.of(values));
		}

		@Override
		public String generate() {
			return values.remove();
		}
	}

	@FunctionalInterface
	private interface ThrowingCall {

		void run();
	}
}
