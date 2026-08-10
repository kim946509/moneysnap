package com.ansandy.moneysnap.identity;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Date;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AppleIdentityTokenVerifierTests {

	private static final Instant NOW = Instant.parse("2026-08-10T12:00:00Z");
	private static KeyPair keyPair;

	@BeforeAll
	static void createSigningKey() throws Exception {
		KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
		generator.initialize(2048);
		keyPair = generator.generateKeyPair();
	}

	@Test
	void acceptsAValidAppleIdentityToken() throws Exception {
		AppleIdentityTokenVerifier verifier = verifier();
		String rawNonce = "request-nonce";

		VerifiedAppleIdentity identity = verifier.verify(signedToken(
				"https://appleid.apple.com",
				"com.ansandy.moneysnap",
				"apple-subject",
				hash(rawNonce),
				Instant.parse("2099-01-01T00:00:00Z")), rawNonce);

		assertThat(identity.subject()).isEqualTo("apple-subject");
	}

	@Test
	void rejectsAnInvalidAppleIssuer() throws Exception {
		assertUnauthorized(signedToken(
				"https://attacker.example",
				"com.ansandy.moneysnap",
				"apple-subject",
				hash("request-nonce"),
				Instant.parse("2099-01-01T00:00:00Z")), "request-nonce");
	}

	@Test
	void rejectsAnInvalidAppleAudience() throws Exception {
		assertUnauthorized(signedToken(
				"https://appleid.apple.com",
				"another.app",
				"apple-subject",
				hash("request-nonce"),
				Instant.parse("2099-01-01T00:00:00Z")), "request-nonce");
	}

	@Test
	void rejectsAnExpiredAppleIdentityToken() throws Exception {
		assertUnauthorized(signedToken(
				"https://appleid.apple.com",
				"com.ansandy.moneysnap",
				"apple-subject",
				hash("request-nonce"),
				NOW.minusSeconds(1)), "request-nonce");
	}

	@Test
	void rejectsAnInvalidNonce() throws Exception {
		assertUnauthorized(signedToken(
				"https://appleid.apple.com",
				"com.ansandy.moneysnap",
				"apple-subject",
				hash("signed-nonce"),
				Instant.parse("2099-01-01T00:00:00Z")), "different-nonce");
	}

	@Test
	void rejectsAClaimHashReplayedAsTheRawNonce() throws Exception {
		String rawNonce = "request-nonce";
		String claimHash = hash(rawNonce);

		assertUnauthorized(signedToken(
				"https://appleid.apple.com",
				"com.ansandy.moneysnap",
				"apple-subject",
				claimHash,
				Instant.parse("2099-01-01T00:00:00Z")), claimHash);
	}

	@Test
	void rejectsAnInvalidSignature() throws Exception {
		String valid = signedToken(
				"https://appleid.apple.com",
				"com.ansandy.moneysnap",
				"apple-subject",
				hash("request-nonce"),
				Instant.parse("2099-01-01T00:00:00Z"));
		String[] parts = valid.split("\\.");
		int changedIndex = parts[2].length() / 2;
		char current = parts[2].charAt(changedIndex);
		char replacement = current == 'A' ? 'B' : 'A';
		parts[2] = parts[2].substring(0, changedIndex)
				+ replacement
				+ parts[2].substring(changedIndex + 1);

		assertUnauthorized(String.join(".", parts), "request-nonce");
	}

	private static AppleIdentityTokenVerifier verifier() {
		NimbusJwtDecoder decoder = NimbusJwtDecoder
				.withPublicKey((RSAPublicKey) keyPair.getPublic())
				.signatureAlgorithm(SignatureAlgorithm.RS256)
				.build();
		return new AppleIdentityTokenVerifier(
				decoder,
				"com.ansandy.moneysnap",
				Clock.fixed(NOW, ZoneOffset.UTC));
	}

	private static void assertUnauthorized(String identityToken, String nonce) {
		assertThatThrownBy(() -> verifier().verify(identityToken, nonce))
				.isInstanceOf(IdentitySessionException.class)
				.extracting(error -> ((IdentitySessionException) error).failure())
				.isEqualTo(IdentitySessionFailure.UNAUTHORIZED);
	}

	private static String hash(String rawNonce) {
		return new Sha256TokenHasher().hash(rawNonce);
	}

	private static String signedToken(
			String issuer,
			String audience,
			String subject,
			String nonce,
			Instant expiresAt) throws Exception {
		SignedJWT token = new SignedJWT(
				new JWSHeader.Builder(JWSAlgorithm.RS256).keyID("apple-test-key").build(),
				new JWTClaimsSet.Builder()
						.issuer(issuer)
						.audience(audience)
						.subject(subject)
						.issueTime(Date.from(NOW.minusSeconds(10)))
						.expirationTime(Date.from(expiresAt))
						.claim("nonce", nonce)
						.build());
		token.sign(new RSASSASigner((RSAPrivateKey) keyPair.getPrivate()));
		return token.serialize();
	}
}
