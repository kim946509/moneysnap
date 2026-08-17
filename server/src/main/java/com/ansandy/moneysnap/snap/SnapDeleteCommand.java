package com.ansandy.moneysnap.snap;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Objects;
import java.util.UUID;

record SnapDeleteCommand(String clientMutationId, UUID snapId) {

    SnapDeleteCommand {
        if (clientMutationId == null || clientMutationId.isBlank()
                || clientMutationId.codePointCount(0, clientMutationId.length()) > 128) {
            throw new IllegalArgumentException("clientMutationId must be 1 to 128 nonblank characters");
        }
        Objects.requireNonNull(snapId, "snapId");
    }

    String fingerprint() {
        String semanticPayload = "snap-delete:v1\nsnapId=%s".formatted(snapId);
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(semanticPayload.getBytes(StandardCharsets.UTF_8)));
        }
        catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }
}
