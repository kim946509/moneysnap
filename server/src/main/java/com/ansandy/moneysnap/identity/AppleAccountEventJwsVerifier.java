package com.ansandy.moneysnap.identity;

import java.time.Clock;
import java.time.DateTimeException;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Objects;

import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;

final class AppleAccountEventJwsVerifier implements AppleAccountEventVerifier {

	private static final String APPLE_ISSUER = "https://appleid.apple.com";
	private static final Duration CLOCK_SKEW = Duration.ofMinutes(5);

	private final JwtDecoder decoder;
	private final String audience;
	private final Clock clock;

	AppleAccountEventJwsVerifier(JwtDecoder decoder, String audience, Clock clock) {
		this.decoder = Objects.requireNonNull(decoder);
		this.audience = requireText(audience, 255);
		this.clock = Objects.requireNonNull(clock);
	}

	@Override
	public VerifiedAppleAccountEvent verify(String payload) {
		try {
			Jwt jwt = decoder.decode(requireText(payload, 8192));
			List<String> audiences = jwt.getAudience();
			Instant issuedAt = jwt.getIssuedAt();
			if (!APPLE_ISSUER.equals(String.valueOf(jwt.getIssuer()))
					|| audiences == null
					|| !audiences.contains(audience)
					|| issuedAt == null
					|| issuedAt.isAfter(clock.instant().plus(CLOCK_SKEW))) {
				throw unauthorized();
			}

			Map<String, Object> event = jwt.getClaimAsMap("events");
			if (event == null) {
				throw unauthorized();
			}
			return new VerifiedAppleAccountEvent(
					requireText(jwt.getId(), 255),
					AppleAccountEventType.fromWire(requireText(asString(event.get("type")), 64)),
					requireText(asString(event.get("sub")), 255),
					eventTime(event.get("event_time")));
		}
		catch (JwtException | ClassCastException | DateTimeException exception) {
			throw unauthorized();
		}
	}

	private static Instant eventTime(Object value) {
		if (!(value instanceof Byte
				|| value instanceof Short
				|| value instanceof Integer
				|| value instanceof Long)) {
			throw unauthorized();
		}
		Number number = (Number) value;
		long epochSecond = number.longValue();
		if (epochSecond < 0) {
			throw unauthorized();
		}
		return Instant.ofEpochSecond(epochSecond);
	}

	private static String asString(Object value) {
		return value instanceof String text ? text : null;
	}

	private static String requireText(String value, int maximumLength) {
		if (value == null || value.isBlank() || value.length() > maximumLength) {
			throw unauthorized();
		}
		return value;
	}

	private static AppleAccountEventException unauthorized() {
		return new AppleAccountEventException(AppleAccountEventFailure.UNAUTHORIZED);
	}
}

interface AppleAccountEventVerifier {

	VerifiedAppleAccountEvent verify(String payload);
}

record VerifiedAppleAccountEvent(
		String eventId,
		AppleAccountEventType type,
		String subject,
		Instant eventTime) {
}

enum AppleAccountEventType {
	CONSENT_REVOKED("consent-revoked"),
	ACCOUNT_DELETED("account-deleted"),
	EMAIL_ENABLED("email-enabled"),
	EMAIL_DISABLED("email-disabled");

	private final String wireValue;

	AppleAccountEventType(String wireValue) {
		this.wireValue = wireValue;
	}

	static AppleAccountEventType fromWire(String value) {
		for (AppleAccountEventType type : values()) {
			if (type.wireValue.equals(value)) {
				return type;
			}
		}
		throw new AppleAccountEventException(AppleAccountEventFailure.UNSUPPORTED_TYPE);
	}
}

enum AppleAccountEventFailure {
	UNAUTHORIZED,
	UNSUPPORTED_TYPE
}

final class AppleAccountEventException extends RuntimeException {

	private final AppleAccountEventFailure failure;

	AppleAccountEventException(AppleAccountEventFailure failure) {
		this.failure = Objects.requireNonNull(failure);
	}

	AppleAccountEventFailure failure() {
		return failure;
	}
}
