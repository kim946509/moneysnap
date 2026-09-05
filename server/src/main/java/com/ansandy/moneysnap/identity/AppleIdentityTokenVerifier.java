package com.ansandy.moneysnap.identity;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Objects;

import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;

final class AppleIdentityTokenVerifier implements AppleIdentityVerifier {

	private static final String APPLE_ISSUER = "https://appleid.apple.com";

	private final JwtDecoder decoder;
	private final String audience;
	private final Clock clock;

	AppleIdentityTokenVerifier(JwtDecoder decoder, String audience, Clock clock) {
		this.decoder = Objects.requireNonNull(decoder);
		this.audience = requireText(audience);
		this.clock = Objects.requireNonNull(clock);
	}

	@Override
	public VerifiedAppleIdentity verify(String identityToken, String expectedNonce) {
		try {
			Jwt jwt = decoder.decode(requireText(identityToken));
			Instant expiresAt = jwt.getExpiresAt();
			List<String> audiences = jwt.getAudience();
			String nonce = jwt.getClaimAsString("nonce");
			if (!issuerMatches(jwt)
					|| audiences == null
					|| !audiences.contains(audience)
					|| expiresAt == null
					|| !expiresAt.isAfter(clock.instant())
					|| !nonceMatches(expectedNonce, nonce)) {
				throw unauthorized();
			}
			return new VerifiedAppleIdentity(requireText(jwt.getSubject()));
		}
		catch (JwtException | IllegalArgumentException exception) {
			throw unauthorized();
		}
	}

	private static boolean issuerMatches(Jwt jwt) {
		String claimIssuer = jwt.getClaimAsString("iss");
		if (APPLE_ISSUER.equals(claimIssuer)) {
			return true;
		}
		return jwt.getIssuer() != null && APPLE_ISSUER.equals(jwt.getIssuer().toString());
	}

	private static boolean nonceMatches(String expectedNonce, String actualNonce) {
		if (actualNonce == null || actualNonce.isBlank()) {
			return true;
		}
		return sameValue(new Sha256TokenHasher().hash(requireText(expectedNonce)), actualNonce);
	}

	private static boolean sameValue(String expected, String actual) {
		if (actual == null) {
			return false;
		}
		return MessageDigest.isEqual(
				expected.getBytes(StandardCharsets.UTF_8),
				actual.getBytes(StandardCharsets.UTF_8));
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
