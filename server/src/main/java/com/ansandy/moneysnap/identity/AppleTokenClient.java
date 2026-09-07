package com.ansandy.moneysnap.identity;

import java.net.URI;
import java.util.Map;
import java.util.Objects;
import java.util.function.Supplier;

import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.MediaType;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;

final class AppleTokenClient implements AppleTokenExchanger {

	private static final ParameterizedTypeReference<Map<String, Object>> JSON_OBJECT =
			new ParameterizedTypeReference<>() {
			};

	private final RestClient restClient;
	private final URI tokenUri;
	private final String clientId;
	private final Supplier<String> clientSecret;

	AppleTokenClient(
			RestClient restClient,
			URI tokenUri,
			String clientId,
			Supplier<String> clientSecret) {
		this.restClient = Objects.requireNonNull(restClient);
		this.tokenUri = Objects.requireNonNull(tokenUri);
		this.clientId = requireText(clientId);
		this.clientSecret = Objects.requireNonNull(clientSecret);
	}

	@Override
	public AppleTokenExchange exchange(String authorizationCode) {
		LinkedMultiValueMap<String, String> form = new LinkedMultiValueMap<>();
		form.add("client_id", clientId);
		form.add("client_secret", requireText(clientSecret.get()));
		form.add("code", requireText(authorizationCode));
		form.add("grant_type", "authorization_code");
		try {
			Map<String, Object> response = restClient.post()
					.uri(tokenUri)
					.contentType(MediaType.APPLICATION_FORM_URLENCODED)
					.body(form)
					.retrieve()
					.body(JSON_OBJECT);
			if (response == null) {
				throw unauthorized();
			}
			return new AppleTokenExchange(text(response.get("id_token")), text(response.get("refresh_token")));
		}
		catch (RestClientException exception) {
			throw unauthorized();
		}
	}

	private static String text(Object value) {
		return value == null ? null : value.toString();
	}

	private static String requireText(String value) {
		if (value == null || value.isBlank()) {
			throw unauthorized();
		}
		return value;
	}

	private static IdentitySessionException unauthorized() {
		return new IdentitySessionException(IdentitySessionFailure.UNAUTHORIZED);
	}
}

record AppleTokenExchange(String identityToken, String refreshToken) {

	AppleTokenExchange {
		if (identityToken == null || identityToken.isBlank()
				|| refreshToken == null || refreshToken.isBlank()) {
			throw new IdentitySessionException(IdentitySessionFailure.UNAUTHORIZED);
		}
	}
}
