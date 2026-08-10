package com.ansandy.moneysnap.identity;

import java.net.URI;
import java.time.Clock;

import javax.sql.DataSource;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DataSourceTransactionManager;
import org.springframework.security.oauth2.jose.jws.SignatureAlgorithm;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.client.RestClient;

@Configuration(proxyBeanMethods = false)
class IdentityConfiguration {

	@Bean
	Clock identityClock() {
		return Clock.systemUTC();
	}

	@Bean
	IdentitySessionService identitySessionService(DataSource dataSource, Clock identityClock) {
		JdbcIdentitySessionStore store = new JdbcIdentitySessionStore(
				JdbcClient.create(dataSource),
				new TransactionTemplate(new DataSourceTransactionManager(dataSource)));
		return new IdentitySessionService(
				store,
				new SecureSessionTokenGenerator(),
				new Sha256TokenHasher(),
				identityClock);
	}

	@Bean
	@ConditionalOnProperty(name = "moneysnap.apple.enabled", havingValue = "true")
	AppleAuthorizationGateway appleAuthorizationGateway(
			Clock identityClock,
			@Value("${moneysnap.apple.client-id}") String clientId,
			@Value("${moneysnap.apple.team-id}") String teamId,
			@Value("${moneysnap.apple.key-id}") String keyId,
			@Value("${moneysnap.apple.private-key}") String privateKey,
			@Value("${moneysnap.apple.refresh-token-encryption-key}") String encryptionKey,
			@Value("${moneysnap.apple.jwk-set-uri:https://appleid.apple.com/auth/keys}") String jwkSetUri,
			@Value("${moneysnap.apple.token-uri:https://appleid.apple.com/auth/token}") String tokenUri) {
		NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(jwkSetUri)
				.jwsAlgorithm(SignatureAlgorithm.RS256)
				.build();
		AppleClientSecretProvider clientSecret = new AppleClientSecretProvider(
				teamId,
				clientId,
				keyId,
				privateKey.replace("\\n", "\n"),
				identityClock);
		return new AppleAuthorizationAdapter(
				new AppleIdentityTokenVerifier(decoder, clientId, identityClock),
				new AppleTokenClient(RestClient.create(), URI.create(tokenUri), clientId, clientSecret),
				new AppleRefreshTokenCipher(encryptionKey));
	}

	@Bean
	@ConditionalOnProperty(
			name = "moneysnap.apple.enabled",
			havingValue = "false",
			matchIfMissing = true)
	AppleAuthorizationGateway unavailableAppleAuthorizationGateway() {
		return request -> {
			throw new IdentitySessionException(IdentitySessionFailure.UNAUTHORIZED);
		};
	}
}
