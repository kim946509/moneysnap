package com.ansandy.moneysnap.snap;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Objects;
import java.util.UUID;

record SnapReviseCommand(
        String clientMutationId,
        int expectedVersion,
        SnapCategory category,
        KrwAmount amount) {

    SnapReviseCommand {
        if (clientMutationId == null || clientMutationId.isBlank()
                || clientMutationId.codePointCount(0, clientMutationId.length()) > 128) {
            throw new IllegalArgumentException("clientMutationId must be 1 to 128 nonblank characters");
        }
        if (expectedVersion < 1) {
            throw new IllegalArgumentException("expectedVersion must be a positive integer");
        }
        Objects.requireNonNull(category, "category");
        Objects.requireNonNull(amount, "amount");
    }

    String fingerprint(UUID snapId) {
        String semanticPayload = "snap-revise:v1\nsnapId=%s\nexpectedVersion=%d\ncategory=%s\namountWon=%d"
                .formatted(snapId, expectedVersion, category.code(), amount.value());
        return sha256(semanticPayload);
    }

    private static String sha256(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        }
        catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }
}
