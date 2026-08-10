package com.ansandy.moneysnap.identity;

import java.net.URI;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.web.client.RestClient;

import static org.springframework.test.web.client.ExpectedCount.once;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.content;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.method;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withBadRequest;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AppleTokenRevocationClientTests {

	@Test
	void revokesAnAppleRefreshToken() {
		RestClient.Builder builder = RestClient.builder();
		MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
		AppleTokenRevocationClient client = new AppleTokenRevocationClient(
				builder.build(),
				URI.create("https://appleid.apple.com/auth/revoke"),
				"com.ansandy.moneysnap",
				() -> "generated-client-secret");
		server.expect(once(), requestTo("https://appleid.apple.com/auth/revoke"))
				.andExpect(method(HttpMethod.POST))
				.andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_FORM_URLENCODED))
				.andExpect(content().string(org.hamcrest.Matchers.containsString("client_id=com.ansandy.moneysnap")))
				.andExpect(content().string(org.hamcrest.Matchers.containsString("client_secret=generated-client-secret")))
				.andExpect(content().string(org.hamcrest.Matchers.containsString("token=apple-refresh-token")))
				.andExpect(content().string(org.hamcrest.Matchers.containsString("token_type_hint=refresh_token")))
				.andRespond(withSuccess());

		client.revoke("apple-refresh-token");

		server.verify();
	}

	@Test
	void reportsAnAppleRevocationFailure() {
		RestClient.Builder builder = RestClient.builder();
		MockRestServiceServer server = MockRestServiceServer.bindTo(builder).build();
		AppleTokenRevocationClient client = new AppleTokenRevocationClient(
				builder.build(),
				URI.create("https://appleid.apple.com/auth/revoke"),
				"com.ansandy.moneysnap",
				() -> "generated-client-secret");
		server.expect(once(), requestTo("https://appleid.apple.com/auth/revoke"))
				.andRespond(withBadRequest().body("""
						{"error":"invalid_client"}
						""").contentType(MediaType.APPLICATION_JSON));

		assertThatThrownBy(() -> client.revoke("apple-refresh-token"))
				.isInstanceOf(AppleRevocationException.class);
		server.verify();
	}

	@Test
	void reportsAClientSecretGenerationFailureAsRevocationFailure() {
		AppleTokenRevocationClient client = new AppleTokenRevocationClient(
				RestClient.create(),
				URI.create("https://appleid.apple.com/auth/revoke"),
				"com.ansandy.moneysnap",
				() -> {
					throw new IllegalStateException("test client-secret failure");
				});

		assertThatThrownBy(() -> client.revoke("apple-refresh-token"))
				.isInstanceOf(AppleRevocationException.class);
	}
}
