package com.ansandy.moneysnap.snap;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.HexFormat;
import java.util.Objects;

record SnapRecordCommand(
        String clientMutationId,
        LocalDate localDay,
        String timeZone,
        SnapCategory category,
        KrwAmount amount) {

    SnapRecordCommand {
        if (clientMutationId == null || clientMutationId.isBlank()
                || clientMutationId.codePointCount(0, clientMutationId.length()) > 128) {
            throw new IllegalArgumentException("clientMutationId must be 1 to 128 nonblank characters");
        }
        Objects.requireNonNull(localDay, "localDay");
        if (timeZone == null || timeZone.isBlank()) {
            throw new IllegalArgumentException("timeZone is required");
        }
        Objects.requireNonNull(category, "category");
        Objects.requireNonNull(amount, "amount");
    }

    void validateLocalDay(Clock clock) {
        Objects.requireNonNull(clock, "clock");
        if (!"UTC".equals(timeZone)
                && (!timeZone.contains("/") || !ZoneId.getAvailableZoneIds().contains(timeZone))) {
            throw new IllegalArgumentException("timeZone must be a tzdb region or UTC");
        }
        LocalDate current = LocalDate.ofInstant(clock.instant(), ZoneId.of(timeZone));
        if (!localDay.equals(current) && !localDay.equals(current.minusDays(1))) {
            throw new IllegalArgumentException("localDay must be current or previous day");
        }
    }

    String fingerprint() {
        String semanticPayload = "snap-record:v1\nlocalDay=%s\ntimeZone=%s\ncategory=%s\namountWon=%d".formatted(
                localDay, timeZone, category.code(), amount.value());
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(semanticPayload.getBytes(StandardCharsets.UTF_8)));
        }
        catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }
}
