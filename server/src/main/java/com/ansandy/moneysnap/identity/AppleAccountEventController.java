package com.ansandy.moneysnap.identity;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth/apple/events")
class AppleAccountEventController {

	private final AppleAccountEventVerifier verifier;
	private final AppleAccountEventService events;

	AppleAccountEventController(
			AppleAccountEventVerifier verifier,
			AppleAccountEventService events) {
		this.verifier = verifier;
		this.events = events;
	}

	@PostMapping
	void receive(@Valid @RequestBody AppleAccountEventRequest request) {
		events.handle(verifier.verify(request.payload()));
	}

	@ExceptionHandler(AppleAccountEventException.class)
	ResponseEntity<Void> invalidEvent(AppleAccountEventException exception) {
		HttpStatus status = exception.failure() == AppleAccountEventFailure.UNSUPPORTED_TYPE
				? HttpStatus.BAD_REQUEST
				: HttpStatus.UNAUTHORIZED;
		return ResponseEntity.status(status).build();
	}

	private record AppleAccountEventRequest(
			@NotBlank @Size(max = 8192) String payload) {
	}
}
