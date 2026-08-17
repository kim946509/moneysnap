package com.ansandy.moneysnap.identity;

import java.nio.charset.StandardCharsets;
import java.security.KeyPairGenerator;
import java.util.Base64;

import com.jayway.jsonpath.JsonPath;
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
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;
import static org.mockito.BDDMockito.willThrow;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static com.ansandy.moneysnap.contract.CanonicalIdentityExamples.json;
import static com.ansandy.moneysnap.contract.CanonicalIdentityExamples.assertExactResponse;

@Testcontainers
@AutoConfigureMockMvc
@SpringBootTest
class AccountDeletionHttpIntegrationTests {

	private static final String ENCRYPTION_KEY = Base64.getEncoder().encodeToString(new byte[32]);
	private static final String PRIVATE_KEY = privateKeyPem();

	@Container
	private static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(
			DockerImageName.parse("postgres:18-alpine"));

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcClient jdbc;

	@MockitoBean
	private AppleAuthorizationGateway appleAuthorization;

	@MockitoBean
	private AppleTokenRevoker appleRevoker;

	@DynamicPropertySource
	static void properties(DynamicPropertyRegistry registry) {
		registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
		registry.add("spring.datasource.username", POSTGRES::getUsername);
		registry.add("spring.datasource.password", POSTGRES::getPassword);
		registry.add("spring.flyway.url", POSTGRES::getJdbcUrl);
		registry.add("spring.flyway.user", POSTGRES::getUsername);
		registry.add("spring.flyway.password", POSTGRES::getPassword);
		registry.add("moneysnap.apple.enabled", () -> "true");
		registry.add("moneysnap.apple.client-id", () -> "com.ansandy.moneysnap");
		registry.add("moneysnap.apple.team-id", () -> "APPLE_TEAM_ID");
		registry.add("moneysnap.apple.key-id", () -> "APPLE_KEY_ID");
		registry.add("moneysnap.apple.private-key", () -> PRIVATE_KEY);
		registry.add("moneysnap.apple.refresh-token-encryption-key", () -> ENCRYPTION_KEY);
	}

	@BeforeEach
	void resetDatabase() {
		jdbc.sql("TRUNCATE TABLE identity_refresh_tokens, identity_sessions, apple_identities, users CASCADE")
				.update();
	}

	@Test
	void deletesTheAuthenticatedAccountAfterAppleReauthentication() throws Exception {
		given(appleAuthorization.authorize(any()))
				.willReturn(authorization("apple-http-delete-subject"));
		SessionResponse session = signIn();

		mockMvc.perform(delete("/api/v1/account")
					.header("Authorization", "Bearer " + session.accessToken())
					.contentType("application/json")
					.content(appleReauthenticationBody()))
				.andExpect(status().isNoContent());

		then(appleRevoker).should().revoke("reauth-apple-refresh-token");
	}

	@Test
	void rejectsAReauthenticatedDifferentAppleUser() throws Exception {
		given(appleAuthorization.authorize(any()))
				.willReturn(
						authorization("current-apple-subject"),
						authorization("different-apple-subject"));
		SessionResponse session = signIn();

		MvcResult result = mockMvc.perform(delete("/api/v1/account")
					.header("Authorization", "Bearer " + session.accessToken())
					.contentType("application/json")
					.content(appleReauthenticationBody()))
				.andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.code").value("APPLE_REAUTHENTICATION_REJECTED"))
				.andExpect(jsonPath("$.correlationId").isNotEmpty())
				.andReturn();

		assertExactFields(result, "error-apple-reauthentication-rejected.json");

		then(appleRevoker).shouldHaveNoInteractions();
	}

	@Test
	void returnsBadGatewayAndPreservesTheAccountWhenAppleRevocationFails() throws Exception {
		given(appleAuthorization.authorize(any()))
				.willReturn(authorization("apple-http-delete-subject"));
		willThrow(new AppleRevocationException()).given(appleRevoker).revoke(anyString());
		SessionResponse session = signIn();

		MvcResult result = mockMvc.perform(delete("/api/v1/account")
					.header("Authorization", "Bearer " + session.accessToken())
					.contentType("application/json")
					.content(appleReauthenticationBody()))
				.andExpect(status().isBadGateway())
				.andExpect(jsonPath("$.code").value("APPLE_REVOCATION_FAILED"))
				.andExpect(jsonPath("$.correlationId").isNotEmpty())
				.andReturn();

		assertExactFields(result, "error-apple-revocation-failed.json");
	}

	@Test
	void rejectsAMalformedReauthenticationRequestWithTheStableErrorContract() throws Exception {
		given(appleAuthorization.authorize(any()))
				.willReturn(authorization("apple-http-delete-subject"));
		SessionResponse session = signIn();

		MvcResult result = mockMvc.perform(delete("/api/v1/account")
					.header("Authorization", "Bearer " + session.accessToken())
					.contentType("application/json")
					.content("{}"))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("INVALID_REQUEST"))
				.andExpect(jsonPath("$.correlationId").isNotEmpty())
				.andReturn();

		assertExactFields(result, "error-invalid-request.json");
	}

	@Test
	void rejectsThePreviousSessionTokensAfterDeletion() throws Exception {
		given(appleAuthorization.authorize(any()))
				.willReturn(authorization("apple-http-delete-subject"));
		SessionResponse session = signIn();
		mockMvc.perform(delete("/api/v1/account")
					.header("Authorization", "Bearer " + session.accessToken())
					.contentType("application/json")
					.content(appleReauthenticationBody()))
				.andExpect(status().isNoContent());

		mockMvc.perform(post("/api/v1/auth/logout")
					.header("Authorization", "Bearer " + session.accessToken()))
				.andExpect(status().isUnauthorized());
		mockMvc.perform(post("/api/v1/auth/refresh")
					.contentType("application/json")
					.content("{\"refreshToken\":\"%s\"}".formatted(session.refreshToken())))
				.andExpect(status().isUnauthorized());
	}

	private SessionResponse signIn() throws Exception {
		byte[] response = mockMvc.perform(post("/api/v1/auth/apple")
					.contentType("application/json")
					.content(appleReauthenticationBody()))
				.andExpect(status().isOk())
				.andReturn()
				.getResponse()
				.getContentAsByteArray();
		String json = new String(response, StandardCharsets.UTF_8);
		return new SessionResponse(
				JsonPath.read(json, "$.accessToken"),
				JsonPath.read(json, "$.refreshToken"));
	}

	private static VerifiedAppleAuthorization authorization(String subject) {
		AppleRefreshTokenCipher cipher = new AppleRefreshTokenCipher(ENCRYPTION_KEY);
		return new VerifiedAppleAuthorization(
				new VerifiedAppleIdentity(subject),
				cipher.encrypt("reauth-apple-refresh-token"));
	}

	private static String appleReauthenticationBody() {
		return json("apple-credential-request.json");
	}

	private static void assertExactFields(MvcResult result, String fixture) throws Exception {
		String response = new String(result.getResponse().getContentAsByteArray(), StandardCharsets.UTF_8);
		assertExactResponse(response, fixture);
	}

	private static String privateKeyPem() {
		try {
			KeyPairGenerator generator = KeyPairGenerator.getInstance("EC");
			generator.initialize(256);
			String encoded = Base64.getMimeEncoder(64, new byte[] {'\n'})
					.encodeToString(generator.generateKeyPair().getPrivate().getEncoded());
			return "-----BEGIN PRIVATE KEY-----\n" + encoded + "\n-----END PRIVATE KEY-----";
		}
		catch (Exception exception) {
			throw new IllegalStateException(exception);
		}
	}

	private record SessionResponse(String accessToken, String refreshToken) {
	}
}
