package com.ansandy.moneysnap.identity;

import java.nio.charset.StandardCharsets;
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
import org.springframework.test.web.servlet.MvcResult;
import com.ansandy.moneysnap.SqliteTestDatabase;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static com.ansandy.moneysnap.contract.CanonicalIdentityExamples.json;
import static com.ansandy.moneysnap.contract.CanonicalIdentityExamples.jsonWithStringProperty;
import static com.ansandy.moneysnap.contract.CanonicalIdentityExamples.assertExactResponse;

@AutoConfigureMockMvc
@SpringBootTest
class AppleAccountEventHttpIntegrationTests {


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
		SqliteTestDatabase.register(registry);
	}

	@BeforeEach
	void resetDatabase() {
		SqliteTestDatabase.clear(jdbc);
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

		MvcResult result = mockMvc.perform(eventRequest("invalid-apple-event"))
				.andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.code").value("APPLE_EVENT_REJECTED"))
				.andExpect(jsonPath("$.correlationId").isNotEmpty())
				.andReturn();

		assertExactFields(result, "error-apple-event-rejected.json");
	}

	@Test
	void rejectsAnUnsupportedSignedEventAsBadRequest() throws Exception {
		given(verifier.verify(anyString())).willThrow(
				new AppleAccountEventException(AppleAccountEventFailure.UNSUPPORTED_TYPE));

		MvcResult result = mockMvc.perform(eventRequest("unsupported-apple-event"))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("APPLE_EVENT_UNSUPPORTED"))
				.andExpect(jsonPath("$.correlationId").isNotEmpty())
				.andReturn();

		assertExactFields(result, "error-apple-event-unsupported.json");
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
		MvcResult result = mockMvc.perform(post("/api/v1/auth/apple/events")
					.contentType("application/json")
					.content("{}"))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("INVALID_REQUEST"))
				.andExpect(jsonPath("$.correlationId").isNotEmpty())
				.andReturn();

		assertExactFields(result, "error-invalid-request.json");
	}

	@Test
	void toleratesFutureFieldsInAnAppleEventRequest() throws Exception {
		given(verifier.verify("signed-apple-event")).willReturn(event(
				"event-future-field",
				AppleAccountEventType.CONSENT_REVOKED));

		mockMvc.perform(post("/api/v1/auth/apple/events")
					.contentType("application/json")
					.content(jsonWithStringProperty(
							"apple-account-event-request.json", "futureField", "ignored")))
				.andExpect(status().isOk());
	}

	private static org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder eventRequest(
			String payload) {
		return post("/api/v1/auth/apple/events")
				.contentType("application/json")
				.content("signed-apple-event".equals(payload)
						? json("apple-account-event-request.json")
						: "{\"payload\":\"%s\"}".formatted(payload));
	}

	private static VerifiedAppleAccountEvent event(String eventId, AppleAccountEventType type) {
		return new VerifiedAppleAccountEvent(
				eventId,
				type,
				"apple-event-subject",
				Instant.parse("2026-08-10T14:00:00Z"));
	}

	private static void assertExactFields(MvcResult result, String fixture) throws Exception {
		String response = new String(result.getResponse().getContentAsByteArray(), StandardCharsets.UTF_8);
		assertExactResponse(response, fixture);
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
