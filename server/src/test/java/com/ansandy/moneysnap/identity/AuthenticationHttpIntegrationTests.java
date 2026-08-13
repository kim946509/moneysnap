package com.ansandy.moneysnap.identity;

import java.nio.charset.StandardCharsets;

import com.jayway.jsonpath.JsonPath;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.Authentication;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static com.ansandy.moneysnap.contract.CanonicalIdentityExamples.json;
import static com.ansandy.moneysnap.contract.CanonicalIdentityExamples.jsonWithStringProperty;
import static com.ansandy.moneysnap.contract.CanonicalIdentityExamples.assertExactResponse;

@Testcontainers
@AutoConfigureMockMvc
@SpringBootTest
@Import(AuthenticationHttpIntegrationTests.ActorProbeConfiguration.class)
class AuthenticationHttpIntegrationTests {

	@Container
	private static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(
			DockerImageName.parse("postgres:18-alpine"));

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private JdbcClient jdbc;

	@MockitoBean
	private AppleAuthorizationGateway appleAuthorization;

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
		jdbc.sql("TRUNCATE TABLE identity_refresh_tokens, identity_sessions, apple_identities, users CASCADE")
				.update();
	}

	@Test
	void signsInWithAppleAndReturnsAMoneySnapSession() throws Exception {
		MvcResult result = signIn()
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.accessToken").isNotEmpty())
				.andExpect(jsonPath("$.accessExpiresAt").isNotEmpty())
				.andExpect(jsonPath("$.refreshToken").isNotEmpty())
				.andExpect(jsonPath("$.refreshExpiresAt").isNotEmpty())
				.andReturn();

		assertExactResponse(responseJson(result), "session-response.json");
	}

	@Test
	void rotatesARefreshToken() throws Exception {
		SessionResponse signedIn = responseOf(signIn().andReturn());

		MvcResult refreshed = mockMvc.perform(post("/api/v1/auth/refresh")
					.contentType("application/json")
					.content("{\"refreshToken\":\"%s\"}".formatted(signedIn.refreshToken())))
				.andExpect(status().isOk())
				.andReturn();

		assertThat(responseOf(refreshed).refreshToken()).isNotEqualTo(signedIn.refreshToken());
	}

	@Test
	void rejectsARefreshTokenAfterRotation() throws Exception {
		SessionResponse signedIn = responseOf(signIn().andReturn());
		mockMvc.perform(refreshRequest(signedIn.refreshToken()))
				.andExpect(status().isOk());

		mockMvc.perform(refreshRequest(signedIn.refreshToken()))
				.andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.code").value("SESSION_REJECTED"))
				.andExpect(jsonPath("$.correlationId").isNotEmpty());
	}

	@Test
	void rejectsThePreviousAccessTokenAfterRotation() throws Exception {
		SessionResponse signedIn = responseOf(signIn().andReturn());
		mockMvc.perform(refreshRequest(signedIn.refreshToken()))
				.andExpect(status().isOk());

		mockMvc.perform(post("/api/v1/auth/logout")
					.header("Authorization", "Bearer " + signedIn.accessToken()))
				.andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.code").value("SESSION_REJECTED"))
				.andExpect(jsonPath("$.correlationId").isNotEmpty());
	}

	@Test
	void authenticatesLogoutWithABearerAccessToken() throws Exception {
		SessionResponse signedIn = responseOf(signIn().andReturn());

		mockMvc.perform(post("/api/v1/auth/logout")
					.header("Authorization", "Bearer " + signedIn.accessToken()))
				.andExpect(status().isNoContent());
	}

	@Test
	void recoversTheSessionActorFromABearerAccessToken() throws Exception {
		SessionResponse signedIn = responseOf(signIn().andReturn());

		mockMvc.perform(get("/api/v1/auth/actor-probe")
					.header("Authorization", "Bearer " + signedIn.accessToken()))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.userId").isNotEmpty())
				.andExpect(jsonPath("$.sessionId").isNotEmpty());
	}

	@Test
	void rejectsTheAccessTokenAfterLogout() throws Exception {
		SessionResponse signedIn = responseOf(signIn().andReturn());
		mockMvc.perform(post("/api/v1/auth/logout")
					.header("Authorization", "Bearer " + signedIn.accessToken()))
				.andExpect(status().isNoContent());

		mockMvc.perform(post("/api/v1/auth/logout")
					.header("Authorization", "Bearer " + signedIn.accessToken()))
				.andExpect(status().isUnauthorized());
	}

	@Test
	void rejectsTheRefreshTokenAfterLogout() throws Exception {
		SessionResponse signedIn = responseOf(signIn().andReturn());
		mockMvc.perform(post("/api/v1/auth/logout")
					.header("Authorization", "Bearer " + signedIn.accessToken()))
				.andExpect(status().isNoContent());

		mockMvc.perform(refreshRequest(signedIn.refreshToken()))
				.andExpect(status().isUnauthorized());
	}

	@Test
	void rejectsAnInvalidAppleAuthorization() throws Exception {
		given(appleAuthorization.authorize(any()))
				.willThrow(new IdentitySessionException(IdentitySessionFailure.UNAUTHORIZED));

		mockMvc.perform(appleSignInRequest())
				.andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.code").value("SESSION_REJECTED"))
				.andExpect(jsonPath("$.correlationId").isNotEmpty());
	}

	@Test
	void invalidAppleAuthorizationDoesNotCreateAUser() throws Exception {
		given(appleAuthorization.authorize(any()))
				.willThrow(new IdentitySessionException(IdentitySessionFailure.UNAUTHORIZED));

		mockMvc.perform(appleSignInRequest())
				.andExpect(status().isUnauthorized());

		int users = jdbc.sql("SELECT count(*) FROM users")
				.query(Integer.class)
				.single();
		assertThat(users).isZero();
	}

	@Test
	void rejectsAMalformedAppleRequest() throws Exception {
		MvcResult result = mockMvc.perform(post("/api/v1/auth/apple")
					.contentType("application/json")
					.content("{}"))
				.andExpect(status().isBadRequest())
				.andExpect(jsonPath("$.code").value("INVALID_REQUEST"))
				.andExpect(jsonPath("$.correlationId").isNotEmpty())
				.andReturn();

		assertExactResponse(responseJson(result), "error-invalid-request.json");
	}

	@Test
	void toleratesFutureFieldsInAnAppleCredentialRequest() throws Exception {
		given(appleAuthorization.authorize(any())).willReturn(new VerifiedAppleAuthorization(
				new VerifiedAppleIdentity("apple-future-field-subject"),
				"v1.encrypted-apple-refresh"));

		mockMvc.perform(post("/api/v1/auth/apple")
					.contentType("application/json")
					.content(jsonWithStringProperty(
							"apple-credential-request.json", "futureField", "ignored")))
				.andExpect(status().isOk());
	}

	@Test
	void canonicalRefreshRequestToleratesFutureFieldsBeforeSemanticRejection() throws Exception {
		mockMvc.perform(post("/api/v1/auth/refresh")
					.contentType("application/json")
					.content(jsonWithStringProperty(
							"refresh-request.json", "futureField", "ignored")))
				.andExpect(status().isUnauthorized())
				.andExpect(jsonPath("$.code").value("SESSION_REJECTED"));
	}

	private org.springframework.test.web.servlet.ResultActions signIn() throws Exception {
		given(appleAuthorization.authorize(any())).willReturn(new VerifiedAppleAuthorization(
				new VerifiedAppleIdentity("apple-http-subject"),
				"v1.encrypted-apple-refresh"));
		return mockMvc.perform(appleSignInRequest());
	}

	private static org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder appleSignInRequest() {
		return post("/api/v1/auth/apple")
				.contentType("application/json")
				.content(json("apple-credential-request.json"));
	}

	private static org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder refreshRequest(
			String refreshToken) {
		return post("/api/v1/auth/refresh")
				.contentType("application/json")
				.content("refresh-token".equals(refreshToken)
						? json("refresh-request.json")
						: "{\"refreshToken\":\"%s\"}".formatted(refreshToken));
	}

	private static SessionResponse responseOf(MvcResult result) {
		String content = new String(result.getResponse().getContentAsByteArray(), StandardCharsets.UTF_8);
		return new SessionResponse(
				JsonPath.read(content, "$.accessToken"),
				JsonPath.read(content, "$.refreshToken"));
	}

	private static String responseJson(MvcResult result) {
		return new String(result.getResponse().getContentAsByteArray(), StandardCharsets.UTF_8);
	}

	private record SessionResponse(String accessToken, String refreshToken) {
	}

	@TestConfiguration(proxyBeanMethods = false)
	static class ActorProbeConfiguration {

		@Bean
		ActorProbeController actorProbeController() {
			return new ActorProbeController();
		}
	}

	@RestController
	static class ActorProbeController {

		@GetMapping("/api/v1/auth/actor-probe")
		SessionActor actor(Authentication authentication) {
			return (SessionActor) authentication.getPrincipal();
		}
	}
}
