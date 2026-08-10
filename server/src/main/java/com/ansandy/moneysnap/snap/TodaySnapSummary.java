package com.ansandy.moneysnap.snap;

import java.time.LocalDate;
import java.util.List;
import java.util.Objects;

final class TodaySnapSummary {

    private final LocalDate date;
    private final List<TodaySnapEntry> entries;
    private final long totalAmount;

    TodaySnapSummary(LocalDate date, List<TodaySnapEntry> entries) {
        this.date = Objects.requireNonNull(date, "date");
        this.entries = List.copyOf(entries);
        if (this.entries.stream().anyMatch(entry -> !entry.recordedOn().equals(date))) {
            throw new IllegalArgumentException("Every Today Snap entry must belong to the summary date");
        }
        this.totalAmount = this.entries.stream()
            .mapToLong(entry -> entry.amount().value())
            .reduce(0L, Math::addExact);
    }

    LocalDate date() {
        return date;
    }

    List<TodaySnapEntry> entries() {
        return entries;
    }

    long totalAmount() {
        return totalAmount;
    }
}
