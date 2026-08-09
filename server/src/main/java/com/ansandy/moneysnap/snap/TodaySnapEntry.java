package com.ansandy.moneysnap.snap;

import java.time.LocalDate;
import java.util.Objects;
import java.util.UUID;

record TodaySnapEntry(
    UUID id,
    LocalDate recordedOn,
    SnapCategory category,
    KrwAmount amount
) {

    TodaySnapEntry {
        Objects.requireNonNull(id, "id");
        Objects.requireNonNull(recordedOn, "recordedOn");
        Objects.requireNonNull(category, "category");
        Objects.requireNonNull(amount, "amount");
    }
}
