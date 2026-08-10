package com.ansandy.moneysnap.identity;

import java.time.Instant;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
class AuthenticationController {

	private final AppleAuthorizationGateway appleAuthorization;
	private final IdentitySessionService sessions;

	AuthenticationController(
			AppleAuthorizationGateway appleAuthorization,
			IdentitySessionService sessions) {
		this.appleAuthorization = appleAuthorization;
		this.sessions = sessions;
	}

	@PostMapping("/apple")
	SessionResponse signInWithApple(@Valid @RequestBody AppleCredentialRequest request) {
		VerifiedAppleAuthorization verified = appleAuthorization.authorize(request.toAuthorizationRequest());
		return SessionResponse.from(sessions.signIn(
				verified.identity(),
				verified.encryptedRefreshToken()));
	}

	@PostMapping("/refresh")
	SessionResponse refresh(@Valid @RequestBody RefreshRequest request) {
		return SessionResponse.from(sessions.refresh(request.refreshToken()));
	}

	@PostMapping("/logout")
	@ResponseStatus(HttpStatus.NO_CONTENT)
	void logout(Authentication authentication) {
		sessions.logout((String) authentication.getCredentials());
	}

	@ExceptionHandler(IdentitySessionException.class)
	@ResponseStatus(HttpStatus.UNAUTHORIZED)
	void unauthorized() {
	}

	private record RefreshRequest(@NotBlank @Size(max = 512) String refreshToken) {
	}

	private record SessionResponse(
			String accessToken,
			Instant accessExpiresAt,
			String refreshToken,
			Instant refreshExpiresAt) {

		private static SessionResponse from(SessionTokens tokens) {
			return new SessionResponse(
					tokens.accessToken(),
					tokens.accessExpiresAt(),
					tokens.refreshToken(),
					tokens.refreshExpiresAt());
		}
	}
}

record AppleCredentialRequest(
		@NotBlank @Size(max = 8192) String identityToken,
		@NotBlank @Size(max = 2048) String authorizationCode,
		@NotBlank @Size(max = 256) String nonce) {

	AppleAuthorizationRequest toAuthorizationRequest() {
		return new AppleAuthorizationRequest(identityToken, authorizationCode, nonce);
	}
}
