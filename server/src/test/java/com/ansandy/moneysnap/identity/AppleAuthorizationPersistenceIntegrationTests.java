package com.ansandy.moneysnap.identity;

import java.net.URI;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.interfaces.RSAPrivateKey;
import java.security.interfaces.RSAPublicKey;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.Date;

import javax.sql.DataSource;

import com.nimbusds.jose.JWSAlgorithm;
import com.nimbusds.jose.JWSHeader;
import com.nimbusds.jose.crypto.RSASSASigner;
import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.SignedJWT;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.jdbc.datasource.DriverManagerDataSource;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.test.web.client.MockRestServiceServer;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.client.RestClient;
import com.ansandy.moneysnap.SqliteTestDatabase;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.client.ExpectedCount.once;
import static org.springframework.test.web.client.match.MockRestRequestMatchers.requestTo;
import static org.springframework.test.web.client.response.MockRestResponseCreators.withSuccess;

class AppleAuthorizationPersistenceIntegrationTests {

	private static final Instant NOW = Instant.parse("2026-08-10T12:00:00Z");
	private static final String SQLITE_URL = SqliteTestDatabase.fileUrl();
	private static final String CLIENT_ID = "com.ansandy.moneysnap";
	private static final String RAW_NONCE = "request-nonce";
	private static final String NONCE_CLAIM = "727e77cae7f89d57cb097b3ddcf620b00abc397d1984003bf453f08324342110";
	private static final URI TOKEN_URI = URI.create("https://appleid.apple.com/auth/token");


	private static KeyPair keyPair;
	private static JdbcClient jdbc;
	private RestClient.Builder appleHttp;
	private MockRestServiceServer appleEndpoint;
	private AppleRefreshTokenCipher cipher;
	private IdentitySessionService sessions;

	@BeforeAll
	static void prepareDatabaseAndSigningKey() throws Exception {
		DataSource dataSource = dataSource();
		Flyway.configure().dataSource(dataSource).load().migrate();
		jdbc = JdbcClient.create(dataSource);
		KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA");
		generator.initialize(2048);
		keyPair = generator.generateKeyPair();
	}

	@BeforeEach
	void setUp() {
		SqliteTestDatabase.clear(jdbc);
		appleHttp = RestClient.builder();
		appleEndpoint = MockRestServiceServer.bindTo(appleHttp).build();
		cipher = new AppleRefreshTokenCipher(Base64.getEncoder().encodeToString(new byte[32]));
		DataSource dataSource = dataSource();
		sessions = new IdentitySessionService(
				new JdbcIdentitySessionStore(
						JdbcClient.create(dataSource),
						new TransactionTemplate(new DataSourceTransactionManager(dataSource))),
				new SecureSessionTokenGenerator(),
				new Sha256TokenHasher(),
				fixedClock());
	}

	@Test
	void storesOnlyCiphertextAfterARealAppleAuthorizationFlow() throws Exception {
		String rawRefreshToken = "raw-apple-refresh-token";
		expectAppleExchange("apple-subject", rawRefreshToken);

		VerifiedAppleAuthorization authorization = adapter().authorize(new AppleAuthorizationRequest(
				signedIdentityToken("apple-subject"),
				"single-use-code",
				RAW_NONCE));
		sessions.signIn(authorization.identity(), authorization.encryptedRefreshToken());

		String stored = jdbc.sql("SELECT encrypted_apple_refresh_token FROM apple_identities")
				.query(String.class)
				.single();
		assertThat(stored).doesNotContain(rawRefreshToken);
		assertThat(cipher.decrypt(stored)).isEqualTo(rawRefreshToken);
		appleEndpoint.verify();
	}

	@Test
	void authorizesWhenTheExchangedIdentityTokenOmitsNonce() throws Exception {
		expectAppleExchange("apple-subject", "raw-apple-refresh-token", false);

		VerifiedAppleAuthorization authorization = adapter().authorize(new AppleAuthorizationRequest(
				signedIdentityToken("apple-subject", true),
				"single-use-code",
				RAW_NONCE));

		assertThat(authorization.identity().subject()).isEqualTo("apple-subject");
		appleEndpoint.verify();
	}

	@Test
	void rejectsDifferentSubjectsAcrossTheAppleExchange() throws Exception {
		expectAppleExchange("different-subject", "raw-apple-refresh-token");

		assertThatThrownBy(() -> adapter().authorize(new AppleAuthorizationRequest(
				signedIdentityToken("client-subject"),
				"single-use-code",
				RAW_NONCE)))
				.isInstanceOf(IdentitySessionException.class)
				.extracting(error -> ((IdentitySessionException) error).failure())
				.isEqualTo(IdentitySessionFailure.UNAUTHORIZED);
		appleEndpoint.verify();
	}

	private AppleAuthorizationAdapter adapter() {
		NimbusJwtDecoder decoder = NimbusJwtDecoder
				.withPublicKey((RSAPublicKey) keyPair.getPublic())
				.signatureAlgorithm(SignatureAlgorithm.RS256)
				.build();
		return new AppleAuthorizationAdapter(
				new AppleIdentityTokenVerifier(decoder, CLIENT_ID, fixedClock()),
				new AppleTokenClient(appleHttp.build(), TOKEN_URI, CLIENT_ID, () -> "client-secret"),
				cipher);
	}

	private void expectAppleExchange(String subject, String refreshToken) throws Exception {
		expectAppleExchange(subject, refreshToken, true);
	}

	private void expectAppleExchange(String subject, String refreshToken, boolean includeNonce) throws Exception {
		appleEndpoint.expect(once(), requestTo(TOKEN_URI))
				.andRespond(withSuccess("""
						{
						  "id_token": "%s",
						  "refresh_token": "%s"
						}
						""".formatted(signedIdentityToken(subject, includeNonce), refreshToken),
						MediaType.APPLICATION_JSON));
	}

	private static String signedIdentityToken(String subject) throws Exception {
		return signedIdentityToken(subject, true);
	}

	private static String signedIdentityToken(String subject, boolean includeNonce) throws Exception {
		JWTClaimsSet.Builder claims = new JWTClaimsSet.Builder()
				.issuer("https://appleid.apple.com")
				.audience(CLIENT_ID)
				.subject(subject)
				.issueTime(Date.from(NOW.minusSeconds(10)))
				.expirationTime(Date.from(Instant.parse("2099-01-01T00:00:00Z")));
		if (includeNonce) {
			claims.claim("nonce", NONCE_CLAIM);
		}
		SignedJWT token = new SignedJWT(
				new JWSHeader.Builder(JWSAlgorithm.RS256).keyID("apple-test-key").build(),
				claims.build());
		token.sign(new RSASSASigner((RSAPrivateKey) keyPair.getPrivate()));
		return token.serialize();
	}

	private static Clock fixedClock() {
		return Clock.fixed(NOW, ZoneOffset.UTC);
	}

	private static DataSource dataSource() {
		return SqliteTestDatabase.dataSource(SQLITE_URL);
	}
}
