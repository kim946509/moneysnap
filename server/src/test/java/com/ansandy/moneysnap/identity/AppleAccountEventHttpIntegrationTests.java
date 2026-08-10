package com.ansandy.moneysnap.identity;

import java.time.Instant;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@Testcontainers
@AutoConfigureMockMvc
@SpringBootTest
class AppleAccountEventHttpIntegrationTests {

	@Container
	private static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(
			DockerImageName.parse("postgres:18-alpine"));

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private IdentitySessionService sessions;

	@Autowired
	private JdbcClient jdbc;

	@MockitoBean
	private AppleAccountEventVerifier verifier;

	@DynamicPropertySource
	static void databaseProperties(DynamicPropertyRegistry registry) {
		registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
		registry.add("spring.datasource.username", POSTGRES::getUsername);
		registry.add("spring.datasource.password", POSTGRES::getPassword);
		registry.add("spring.flyway.url", POSTGRES::getJdbcUrl);
		registry.add("spring.flyway.user", POSTGRES::getUsername);
		registry.add("spring.flyway.password", POSTGRES::getPassword);
	}

	@BeforeEach
	void resetDatabase() {
		jdbc.sql("TRUNCATE TABLE apple_account_event_receipts, identity_refresh_tokens, identity_sessions, apple_identities, users CASCADE")
				.update();
	}

	@Test
	void acceptsAValidAppleEventWithoutBearerAuthentication() throws Exception {
		given(verifier.verify("signed-apple-event")).willReturn(event(
				"event-consent",
				AppleAccountEventType.CONSENT_REVOKED));

		mockMvc.perform(eventRequest("signed-apple-event"))
				.andExpect(status().isOk());
	}

	@Test
	void connectsTheVerifiedEventToTheApplicationService() throws Exception {
		SessionTokens tokens = sessions.signIn(new VerifiedAppleIdentity("apple-event-subject"));
		given(verifier.verify(anyString())).willReturn(event(
				"event-consent",
				AppleAccountEventType.CONSENT_REVOKED));

		mockMvc.perform(eventRequest("signed-apple-event"));

		assertThatThrownByUnauthorized(() -> sessions.authenticate(tokens.accessToken()));
	}

	@Test
	void rejectsAnInvalidSignedEventAsUnauthorized() throws Exception {
		given(verifier.verify(anyString())).willThrow(
				new AppleAccountEventException(AppleAccountEventFailure.UNAUTHORIZED));

		mockMvc.perform(eventRequest("invalid-apple-event"))
				.andExpect(status().isUnauthorized());
	}

	@Test
	void rejectsAnUnsupportedSignedEventAsBadRequest() throws Exception {
		given(verifier.verify(anyString())).willThrow(
				new AppleAccountEventException(AppleAccountEventFailure.UNSUPPORTED_TYPE));

		mockMvc.perform(eventRequest("unsupported-apple-event"))
				.andExpect(status().isBadRequest());
	}

	@Test
	void invalidSignedEventDoesNotCreateAReceipt() throws Exception {
		given(verifier.verify(anyString())).willThrow(
				new AppleAccountEventException(AppleAccountEventFailure.UNAUTHORIZED));

		mockMvc.perform(eventRequest("invalid-apple-event"));

		assertThat(receiptCount()).isZero();
	}

	@Test
	void rejectsAMalformedRequest() throws Exception {
		mockMvc.perform(post("/api/v1/auth/apple/events")
					.contentType("application/json")
					.content("{}"))
				.andExpect(status().isBadRequest());
	}

	private static org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder eventRequest(
			String payload) {
		return post("/api/v1/auth/apple/events")
				.contentType("application/json")
				.content("{\"payload\":\"%s\"}".formatted(payload));
	}

	private static VerifiedAppleAccountEvent event(String eventId, AppleAccountEventType type) {
		return new VerifiedAppleAccountEvent(
				eventId,
				type,
				"apple-event-subject",
				Instant.parse("2026-08-10T14:00:00Z"));
	}

	private int receiptCount() {
		return jdbc.sql("SELECT count(*) FROM apple_account_event_receipts")
				.query(Integer.class)
				.single();
	}

	private static void assertThatThrownByUnauthorized(ThrowingCall call) {
		try {
			call.run();
			throw new AssertionError("Expected authentication failure");
		}
		catch (IdentitySessionException exception) {
			assertThat(exception.failure()).isEqualTo(IdentitySessionFailure.UNAUTHORIZED);
		}
	}

	@FunctionalInterface
	private interface ThrowingCall {

		void run();
	}
}
