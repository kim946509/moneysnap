package com.ansandy.moneysnap.identity;

import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

record ApiErrorResponse(ApiErrorCode code, String correlationId) {

	private static final Logger LOGGER = LoggerFactory.getLogger(ApiErrorResponse.class);

	static ApiErrorResponse of(ApiErrorCode code) {
		String correlationId = UUID.randomUUID().toString();
		LOGGER.warn("API request rejected code={} correlationId={}", code, correlationId);
		return new ApiErrorResponse(code, correlationId);
	}
}

enum ApiErrorCode {
	INVALID_REQUEST,
	SESSION_REJECTED,
	APPLE_REAUTHENTICATION_REJECTED,
	APPLE_REVOCATION_FAILED,
	APPLE_EVENT_REJECTED,
	APPLE_EVENT_UNSUPPORTED
}
