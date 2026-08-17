package com.ansandy.moneysnap.identity;

import java.util.Base64;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class AppleRefreshTokenCipherTests {

	private final AppleRefreshTokenCipher cipher = new AppleRefreshTokenCipher(
			Base64.getEncoder().encodeToString(new byte[32]));

	@Test
	void encryptsTheAppleRefreshTokenWithoutExposingPlaintext() {
		String encrypted = cipher.encrypt("apple-refresh-token");

		assertThat(encrypted).doesNotContain("apple-refresh-token");
		assertThat(cipher.decrypt(encrypted)).isEqualTo("apple-refresh-token");
	}
}
