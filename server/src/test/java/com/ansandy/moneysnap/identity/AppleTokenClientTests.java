package com.ansandy.moneysnap.identity;

import java.net.URI;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.ExpectedCount.once;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.content;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withBadRequest;

class AppleTokenClientTests {

	@Test
	void exchangesTheSingleUseAuthorizationCode() {
		RestClient.Builder builder = RestClient.builder();
		MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
		AppleTokenClient client = new AppleTokenClient(
				builder.build(),
				URI.create("https://appleid.apple.com/auth/token"),
				"com.ansandy.moneysnap",
				() -> "generated-client-secret");
		server.expect(once(), requestTo("https://appleid.apple.com/auth/token"))
				.andExpect(method(HttpMethod.POST))
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_FORM_URLENCODED))
				.andExpect(content().string(org.hamcrest.Matchers.containsString("code=single-use-code")))
				.andExpect(content().string(org.hamcrest.Matchers.containsString("grant_type=authorization_code")))
				.andExpect(content().string(org.hamcrest.Matchers.containsString("client_id=com.ansandy.moneysnap")))
				.andExpect(content().string(org.hamcrest.Matchers.containsString("client_secret=generated-client-secret")))
				.andRespond(withSuccess("""
						{
						  "id_token": "exchanged-identity-token",
						  "refresh_token": "apple-refresh-token",
						  "access_token": "apple-access-token",
						  "token_type": "Bearer",
						  "expires_in": 3600
						}
						""", MediaType.APPLICATION_JSON));

		AppleTokenExchange exchange = client.exchange("single-use-code");

		assertThat(exchange.identityToken()).isEqualTo("exchanged-identity-token");
		assertThat(exchange.refreshToken()).isEqualTo("apple-refresh-token");
		server.verify();
	}

	@Test
	void rejectsAnAppleTokenEndpointError() {
		RestClient.Builder builder = RestClient.builder();
		MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
		AppleTokenClient client = new AppleTokenClient(
				builder.build(),
				URI.create("https://appleid.apple.com/auth/token"),
				"com.ansandy.moneysnap",
				() -> "generated-client-secret");
		server.expect(once(), requestTo("https://appleid.apple.com/auth/token"))
				.andRespond(withBadRequest().body("""
						{"error":"invalid_grant"}
						""").contentType(MediaType.APPLICATION_JSON));

		assertThatThrownBy(() -> client.exchange("invalid-code"))
				.isInstanceOf(IdentitySessionException.class)
				.hasMessage(IdentitySessionFailure.UNAUTHORIZED.name());
		server.verify();
	}
}
