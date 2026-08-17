package com.ansandy.moneysnap.identity;

import java.security.GeneralSecurityException;
import java.security.KeyFactory;
import java.security.interfaces.ECPrivateKey;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Date;
import java.util.List;
import java.util.function.Supplier;

import com.nimbusds.jose.JOSEException;
import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.ECDSASigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;

final class AppleClientSecretProvider implements Supplier<String> {

	private static final String APPLE_ISSUER = "https://appleid.apple.com";
	private static final Duration LIFETIME = Duration.ofMinutes(5);

	private final String teamId;
	private final String clientId;
	private final String keyId;
	private final ECPrivateKey privateKey;
	private final Clock clock;

	AppleClientSecretProvider(
			String teamId,
			String clientId,
			String keyId,
			String privateKeyPem,
			Clock clock) {
		this.teamId = requireText(teamId, "Apple team ID");
		this.clientId = requireText(clientId, "Apple client ID");
		this.keyId = requireText(keyId, "Apple key ID");
		this.privateKey = parsePrivateKey(privateKeyPem);
		this.clock = clock;
	}

	@Override
	public String get() {
		Instant issuedAt = clock.instant();
		SignedJWT secret = new SignedJWT(
				new JWSHeader.Builder(JWSAlgorithm.ES256).keyID(keyId).build(),
				new JWTClaimsSet.Builder()
						.issuer(teamId)
						.subject(clientId)
						.audience(List.of(APPLE_ISSUER))
						.issueTime(Date.from(issuedAt))
						.expirationTime(Date.from(issuedAt.plus(LIFETIME)))
						.build());
		try {
			secret.sign(new ECDSASigner(privateKey));
			return secret.serialize();
		}
		catch (JOSEException exception) {
			throw new IllegalStateException("Unable to generate Apple client secret", exception);
		}
	}

	private static ECPrivateKey parsePrivateKey(String pem) {
		try {
			String encoded = requireText(pem, "Apple private key")
					.replace("-----BEGIN PRIVATE KEY-----", "")
					.replace("-----END PRIVATE KEY-----", "")
					.replaceAll("\\s", "");
			byte[] keyBytes = Base64.getDecoder().decode(encoded);
			return (ECPrivateKey) KeyFactory.getInstance("EC")
					.generatePrivate(new PKCS8EncodedKeySpec(keyBytes));
		}
		catch (GeneralSecurityException | IllegalArgumentException exception) {
			throw new IllegalArgumentException("Invalid Apple private key", exception);
		}
	}

	private static String requireText(String value, String name) {
		if (value == null || value.isBlank()) {
			throw new IllegalArgumentException(name + " is required");
		}
		return value;
	}
}
