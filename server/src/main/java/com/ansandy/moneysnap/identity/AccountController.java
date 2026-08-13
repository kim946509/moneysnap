package com.ansandy.moneysnap.identity;

import jakarta.validation.Valid;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.ansandy.moneysnap.shared.AuthenticatedUser;
import com.ansandy.moneysnap.shared.http.ApiErrorCode;
import com.ansandy.moneysnap.shared.http.ApiErrorResponse;

@RestController
@RequestMapping("/api/v1/account")
@ConditionalOnProperty(name = "moneysnap.apple.enabled", havingValue = "true")
class AccountController {

	private final AppleAuthorizationGateway appleAuthorization;
	private final AccountDeletionService deletion;

	AccountController(
			AppleAuthorizationGateway appleAuthorization,
			AccountDeletionService deletion) {
		this.appleAuthorization = appleAuthorization;
		this.deletion = deletion;
	}

	@DeleteMapping
	@ResponseStatus(HttpStatus.NO_CONTENT)
	void delete(
			Authentication authentication,
			@Valid @RequestBody AppleCredentialRequest request) {
		VerifiedAppleAuthorization verified = appleAuthorization.authorize(request.toAuthorizationRequest());
		deletion.delete(((AuthenticatedUser) authentication.getPrincipal()).userId(), verified);
	}

	@ExceptionHandler(IdentitySessionException.class)
	@ResponseStatus(HttpStatus.UNAUTHORIZED)
	ApiErrorResponse unauthorized() {
		return ApiErrorResponse.of(ApiErrorCode.APPLE_REAUTHENTICATION_REJECTED);
	}

	@ExceptionHandler(AppleRevocationException.class)
	@ResponseStatus(HttpStatus.BAD_GATEWAY)
	ApiErrorResponse revocationFailed() {
		return ApiErrorResponse.of(ApiErrorCode.APPLE_REVOCATION_FAILED);
	}
}
