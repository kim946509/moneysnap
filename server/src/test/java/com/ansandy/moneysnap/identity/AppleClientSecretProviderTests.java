package com.ansandy.moneysnap.identity;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.interfaces.ECPublicKey;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Base64;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.crypto.ECDSAVerifier;
import com.nimbusds.jwt.SignedJWT;
import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class AppleClientSecretProviderTests {

	private static final Instant NOW = Instant.parse("2026-08-10T12:00:00Z");

	@Test
	void generatesAShortLivedAppleClientSecret() throws Exception {
		KeyPairGenerator generator = KeyPairGenerator.getInstance("EC");
		generator.initialize(256);
		KeyPair keyPair = generator.generateKeyPair();
		AppleClientSecretProvider provider = new AppleClientSecretProvider(
				"APPLE_TEAM_ID",
				"com.ansandy.moneysnap",
				"APPLE_KEY_ID",
				pem(keyPair),
				Clock.fixed(NOW, ZoneOffset.UTC));

		SignedJWT secret = SignedJWT.parse(provider.get());

		assertThat(secret.verify(new ECDSAVerifier((ECPublicKey) keyPair.getPublic()))).isTrue();
		assertThat(secret.getHeader().getAlgorithm()).isEqualTo(JWSAlgorithm.ES256);
		assertThat(secret.getHeader().getKeyID()).isEqualTo("APPLE_KEY_ID");
		assertThat(secret.getJWTClaimsSet().getIssuer()).isEqualTo("APPLE_TEAM_ID");
		assertThat(secret.getJWTClaimsSet().getSubject()).isEqualTo("com.ansandy.moneysnap");
		assertThat(secret.getJWTClaimsSet().getAudience()).containsExactly("https://appleid.apple.com");
		assertThat(secret.getJWTClaimsSet().getIssueTime()).isEqualTo(java.util.Date.from(NOW));
		assertThat(secret.getJWTClaimsSet().getExpirationTime())
				.isEqualTo(java.util.Date.from(NOW.plus(Duration.ofMinutes(5))));
	}

	private static String pem(KeyPair keyPair) {
		String encoded = Base64.getMimeEncoder(64, new byte[] {'\n'})
				.encodeToString(keyPair.getPrivate().getEncoded());
		return "-----BEGIN PRIVATE KEY-----\n" + encoded + "\n-----END PRIVATE KEY-----";
	}
}
