package com.ansandy.moneysnap.shared;

import java.util.Objects;
import java.util.UUID;

public record AuthenticatedUser(UUID userId) {

    public AuthenticatedUser {
        Objects.requireNonNull(userId, "userId");
    }
}
