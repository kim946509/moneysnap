package com.ansandy.moneysnap.shared.http;

import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public record ApiErrorResponse(ApiErrorCode code, String correlationId) {

    private static final Logger LOGGER = LoggerFactory.getLogger(ApiErrorResponse.class);

    public static ApiErrorResponse of(ApiErrorCode code) {
        String correlationId = UUID.randomUUID().toString();
        LOGGER.warn("API request rejected code={} correlationId={}", code, correlationId);
        return new ApiErrorResponse(code, correlationId);
    }
}
