package com.ansandy.moneysnap.identity;

import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Date;
import java.util.Map;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class AppleAccountEventJwsVerifierTests {

	private static final Instant NOW = Instant.parse("2026-08-10T12:00:00Z");
	private static KeyPair keyPair;

	@BeforeAll
	static void createSigningKey() throws Exception {
		KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
		generator.initialize(2048);
		keyPair = generator.generateKeyPair();
	}

	@Test
	void verifiesTheSignedAppleAccountEvent() throws Exception {
		VerifiedAppleAccountEvent event = verifier().verify(signedToken(
				"https://appleid.apple.com",
				"com.ansandy.moneysnap",
				NOW.minusSeconds(10),
				"event-1",
				"consent-revoked",
				"apple-subject",
				NOW.minusSeconds(20)));

		assertThat(event).isEqualTo(new VerifiedAppleAccountEvent(
				"event-1",
				AppleAccountEventType.CONSENT_REVOKED,
				"apple-subject",
				NOW.minusSeconds(20)));
	}

	@ParameterizedTest
	@CsvSource({
			"consent-revoked, CONSENT_REVOKED",
			"account-deleted, ACCOUNT_DELETED",
			"email-enabled, EMAIL_ENABLED",
			"email-disabled, EMAIL_DISABLED"
	})
	void mapsEveryDocumentedEventType(String wireValue, AppleAccountEventType expected) throws Exception {
		assertThat(verifier().verify(validToken(wireValue)).type()).isEqualTo(expected);
	}

	@Test
	void rejectsAnInvalidIssuer() throws Exception {
		assertFailure(signedToken(
				"https://attacker.example",
				"com.ansandy.moneysnap",
				NOW,
				"event-1",
				"consent-revoked",
				"apple-subject",
				NOW), AppleAccountEventFailure.UNAUTHORIZED);
	}

	@Test
	void rejectsAnInvalidAudience() throws Exception {
		assertFailure(signedToken(
				"https://appleid.apple.com",
				"another.app",
				NOW,
				"event-1",
				"consent-revoked",
				"apple-subject",
				NOW), AppleAccountEventFailure.UNAUTHORIZED);
	}

	@Test
	void rejectsAnIssuedAtMoreThanFiveMinutesInTheFuture() throws Exception {
		assertFailure(signedToken(
				"https://appleid.apple.com",
				"com.ansandy.moneysnap",
				NOW.plusSeconds(301),
				"event-1",
				"consent-revoked",
				"apple-subject",
				NOW), AppleAccountEventFailure.UNAUTHORIZED);
	}

	@Test
	void rejectsAMissingEventIdentifier() throws Exception {
		assertFailure(signedToken(
				"https://appleid.apple.com",
				"com.ansandy.moneysnap",
				NOW,
				null,
				"consent-revoked",
				"apple-subject",
				NOW), AppleAccountEventFailure.UNAUTHORIZED);
	}

	@Test
	void rejectsAMissingEventSubject() throws Exception {
		assertFailure(signedTokenWithEvents(Map.of(
				"type", "consent-revoked",
				"event_time", NOW.getEpochSecond())), AppleAccountEventFailure.UNAUTHORIZED);
	}

	@Test
	void rejectsANonNumericEventTime() throws Exception {
		assertFailure(signedTokenWithEvents(Map.of(
				"type", "consent-revoked",
				"sub", "apple-subject",
				"event_time", "not-a-time")), AppleAccountEventFailure.UNAUTHORIZED);
	}

	@Test
	void rejectsAFractionalEventTime() throws Exception {
		assertFailure(signedTokenWithEvents(Map.of(
				"type", "consent-revoked",
				"sub", "apple-subject",
				"event_time", 123.9)), AppleAccountEventFailure.UNAUTHORIZED);
	}

	@Test
	void rejectsAnUnknownEventTypeWithoutTreatingItAsAuthenticationFailure() throws Exception {
		assertFailure(validToken("future-event"), AppleAccountEventFailure.UNSUPPORTED_TYPE);
	}

	@Test
	void rejectsAnInvalidSignature() throws Exception {
		String valid = validToken("consent-revoked");
		String[] parts = valid.split("\\.");
		int changedIndex = parts[2].length() / 2;
		char current = parts[2].charAt(changedIndex);
		parts[2] = parts[2].substring(0, changedIndex)
				+ (current == 'A' ? 'B' : 'A')
				+ parts[2].substring(changedIndex + 1);

		assertFailure(String.join(".", parts), AppleAccountEventFailure.UNAUTHORIZED);
	}

	private static AppleAccountEventJwsVerifier verifier() {
		NimbusJwtDecoder decoder = NimbusJwtDecoder
				.withPublicKey((RSAPublicKey) keyPair.getPublic())
				.signatureAlgorithm(SignatureAlgorithm.RS256)
				.build();
		return new AppleAccountEventJwsVerifier(
				decoder,
				"com.ansandy.moneysnap",
				Clock.fixed(NOW, ZoneOffset.UTC));
	}

	private static void assertFailure(String token, AppleAccountEventFailure expected) {
		assertThatThrownBy(() -> verifier().verify(token))
				.isInstanceOf(AppleAccountEventException.class)
				.extracting(error -> ((AppleAccountEventException) error).failure())
				.isEqualTo(expected);
	}

	private static String validToken(String type) throws Exception {
		return signedToken(
				"https://appleid.apple.com",
				"com.ansandy.moneysnap",
				NOW.minusSeconds(10),
				"event-1",
				type,
				"apple-subject",
				NOW.minusSeconds(20));
	}

	private static String signedToken(
			String issuer,
			String audience,
			Instant issuedAt,
			String eventId,
			String type,
			String subject,
			Instant eventTime) throws Exception {
		SignedJWT token = new SignedJWT(
				new JWSHeader.Builder(JWSAlgorithm.RS256).keyID("apple-test-key").build(),
				new JWTClaimsSet.Builder()
						.issuer(issuer)
						.audience(audience)
						.issueTime(Date.from(issuedAt))
						.jwtID(eventId)
						.claim("events", Map.of(
								"type", type,
								"sub", subject,
								"event_time", eventTime.getEpochSecond()))
						.build());
		token.sign(new RSASSASigner((RSAPrivateKey) keyPair.getPrivate()));
		return token.serialize();
	}

	private static String signedTokenWithEvents(Map<String, Object> events) throws Exception {
		SignedJWT token = new SignedJWT(
				new JWSHeader.Builder(JWSAlgorithm.RS256).keyID("apple-test-key").build(),
				new JWTClaimsSet.Builder()
						.issuer("https://appleid.apple.com")
						.audience("com.ansandy.moneysnap")
						.issueTime(Date.from(NOW))
						.jwtID("event-1")
						.claim("events", events)
						.build());
		token.sign(new RSASSASigner((RSAPrivateKey) keyPair.getPrivate()));
		return token.serialize();
	}
}
