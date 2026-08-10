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
import org.springframework.security.oauth2.jwt.JwtDecoder;
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
	JdbcIdentitySessionStore identitySessionStore(DataSource dataSource) {
		return new JdbcIdentitySessionStore(
				JdbcClient.create(dataSource),
				new TransactionTemplate(new DataSourceTransactionManager(dataSource)));
	}

	@Bean
	IdentitySessionService identitySessionService(
			JdbcIdentitySessionStore store,
			Clock identityClock) {
		return new IdentitySessionService(
				store,
				new SecureSessionTokenGenerator(),
				new Sha256TokenHasher(),
				identityClock);
	}

	@Bean
	@ConditionalOnProperty(name = "moneysnap.apple.enabled", havingValue = "true")
	AppleClientSecretProvider appleClientSecretProvider(
			Clock identityClock,
			@Value("${moneysnap.apple.client-id}") String clientId,
			@Value("${moneysnap.apple.team-id}") String teamId,
			@Value("${moneysnap.apple.key-id}") String keyId,
			@Value("${moneysnap.apple.private-key}") String privateKey) {
		return new AppleClientSecretProvider(
				teamId,
				clientId,
				keyId,
				privateKey.replace("\\n", "\n"),
				identityClock);
	}

	@Bean
	@ConditionalOnProperty(name = "moneysnap.apple.enabled", havingValue = "true")
	AppleRefreshTokenCipher appleRefreshTokenCipher(
			@Value("${moneysnap.apple.refresh-token-encryption-key}") String encryptionKey) {
		return new AppleRefreshTokenCipher(encryptionKey);
	}

	@Bean
	@ConditionalOnProperty(name = "moneysnap.apple.enabled", havingValue = "true")
	JwtDecoder appleJwtDecoder(
			@Value("${moneysnap.apple.jwk-set-uri:https://appleid.apple.com/auth/keys}") String jwkSetUri) {
		return NimbusJwtDecoder.withJwkSetUri(jwkSetUri)
				.jwsAlgorithm(SignatureAlgorithm.RS256)
				.build();
	}

	@Bean
	@ConditionalOnProperty(name = "moneysnap.apple.enabled", havingValue = "true")
	AppleAuthorizationGateway appleAuthorizationGateway(
			Clock identityClock,
			AppleClientSecretProvider clientSecret,
			AppleRefreshTokenCipher refreshTokenCipher,
			JwtDecoder appleJwtDecoder,
			@Value("${moneysnap.apple.client-id}") String clientId,
			@Value("${moneysnap.apple.token-uri:https://appleid.apple.com/auth/token}") String tokenUri) {
		return new AppleAuthorizationAdapter(
				new AppleIdentityTokenVerifier(appleJwtDecoder, clientId, identityClock),
				new AppleTokenClient(RestClient.create(), URI.create(tokenUri), clientId, clientSecret),
				refreshTokenCipher);
	}

	@Bean
	@ConditionalOnProperty(name = "moneysnap.apple.enabled", havingValue = "true")
	AppleAccountEventVerifier appleAccountEventVerifier(
			JwtDecoder appleJwtDecoder,
			Clock identityClock,
			@Value("${moneysnap.apple.client-id}") String clientId) {
		return new AppleAccountEventJwsVerifier(appleJwtDecoder, clientId, identityClock);
	}

	@Bean
	AppleAccountEventService appleAccountEventService(
			JdbcIdentitySessionStore store,
			Clock identityClock) {
		return new AppleAccountEventService(store, identityClock);
	}

	@Bean
	@ConditionalOnProperty(name = "moneysnap.apple.enabled", havingValue = "true")
	AppleTokenRevoker appleTokenRevoker(
			AppleClientSecretProvider clientSecret,
			@Value("${moneysnap.apple.client-id}") String clientId,
			@Value("${moneysnap.apple.revoke-uri:https://appleid.apple.com/auth/revoke}") String revokeUri) {
		return new AppleTokenRevocationClient(
				RestClient.create(),
				URI.create(revokeUri),
				clientId,
				clientSecret);
	}

	@Bean
	@ConditionalOnProperty(name = "moneysnap.apple.enabled", havingValue = "true")
	AccountDeletionService accountDeletionService(
			JdbcIdentitySessionStore store,
			AppleRefreshTokenCipher refreshTokenCipher,
			AppleTokenRevoker appleTokenRevoker) {
		return new AccountDeletionService(store, refreshTokenCipher, appleTokenRevoker);
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

	@Bean
	@ConditionalOnProperty(
			name = "moneysnap.apple.enabled",
			havingValue = "false",
			matchIfMissing = true)
	AppleAccountEventVerifier unavailableAppleAccountEventVerifier() {
		return payload -> {
			throw new AppleAccountEventException(AppleAccountEventFailure.UNAUTHORIZED);
		};
	}
}
