package com.ansandy.moneysnap.identity;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.SecureRandom;
import java.util.Base64;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;

final class AppleRefreshTokenCipher {

	private static final String VERSION = "v1";
	private static final byte[] AAD = "moneysnap-apple-refresh:v1".getBytes(StandardCharsets.UTF_8);
	private static final int IV_BYTES = 12;
	private static final int TAG_BITS = 128;

	private final SecretKeySpec key;
	private final SecureRandom secureRandom = new SecureRandom();

	AppleRefreshTokenCipher(String base64Key) {
		byte[] decoded = Base64.getDecoder().decode(base64Key);
		if (decoded.length != 32) {
			throw new IllegalArgumentException("Apple refresh token encryption key must be 32 bytes");
		}
		this.key = new SecretKeySpec(decoded, "AES");
	}

	String encrypt(String refreshToken) {
		if (refreshToken == null || refreshToken.isBlank()) {
			throw new IllegalArgumentException("Apple refresh token is required");
		}
		byte[] iv = new byte[IV_BYTES];
		secureRandom.nextBytes(iv);
		try {
			Cipher cipher = cipher(Cipher.ENCRYPT_MODE, iv);
			byte[] ciphertext = cipher.doFinal(refreshToken.getBytes(StandardCharsets.UTF_8));
			return VERSION + "." + encode(iv) + "." + encode(ciphertext);
		}
		catch (GeneralSecurityException exception) {
			throw new IllegalStateException("Unable to encrypt Apple refresh token", exception);
		}
	}

	String decrypt(String encryptedRefreshToken) {
		String[] parts = encryptedRefreshToken == null ? new String[0] : encryptedRefreshToken.split("\\.");
		if (parts.length != 3 || !VERSION.equals(parts[0])) {
			throw new IllegalArgumentException("Invalid encrypted Apple refresh token");
		}
		try {
			byte[] iv = Base64.getUrlDecoder().decode(parts[1]);
			byte[] ciphertext = Base64.getUrlDecoder().decode(parts[2]);
			Cipher cipher = cipher(Cipher.DECRYPT_MODE, iv);
			return new String(cipher.doFinal(ciphertext), StandardCharsets.UTF_8);
		}
		catch (GeneralSecurityException | IllegalArgumentException exception) {
			throw new IllegalArgumentException("Invalid encrypted Apple refresh token", exception);
		}
	}

	private Cipher cipher(int mode, byte[] iv) throws GeneralSecurityException {
		Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
		cipher.init(mode, key, new GCMParameterSpec(TAG_BITS, iv));
		cipher.updateAAD(AAD);
		return cipher;
	}

	private static String encode(byte[] value) {
		return Base64.getUrlEncoder().withoutPadding().encodeToString(value);
	}
}
