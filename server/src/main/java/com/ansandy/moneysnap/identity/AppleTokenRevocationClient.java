package com.ansandy.moneysnap.identity;

import java.net.URI;
import java.util.Objects;
import java.util.function.Supplier;

import org.springframework.http.MediaType;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

final class AppleTokenRevocationClient implements AppleTokenRevoker {

	private final RestClient restClient;
	private final URI revokeUri;
	private final String clientId;
	private final Supplier<String> clientSecret;

	AppleTokenRevocationClient(
			RestClient restClient,
			URI revokeUri,
			String clientId,
			Supplier<String> clientSecret) {
		this.restClient = Objects.requireNonNull(restClient);
		this.revokeUri = Objects.requireNonNull(revokeUri);
		this.clientId = requireText(clientId);
		this.clientSecret = Objects.requireNonNull(clientSecret);
	}

	@Override
	public void revoke(String refreshToken) {
		try {
			LinkedMultiValueMap<String, String> form = new LinkedMultiValueMap<>();
			form.add("client_id", clientId);
			form.add("client_secret", requireText(clientSecret.get()));
			form.add("token", requireText(refreshToken));
			form.add("token_type_hint", "refresh_token");
			restClient.post()
					.uri(revokeUri)
					.contentType(MediaType.APPLICATION_FORM_URLENCODED)
					.body(form)
					.retrieve()
					.toBodilessEntity();
		}
		catch (RestClientException | IllegalStateException exception) {
			throw new AppleRevocationException();
		}
	}

	private static String requireText(String value) {
		if (value == null || value.isBlank()) {
			throw new AppleRevocationException();
		}
		return value;
	}
}

@FunctionalInterface
interface AppleTokenRevoker {

	void revoke(String refreshToken);
}

final class AppleRevocationException extends RuntimeException {
}
