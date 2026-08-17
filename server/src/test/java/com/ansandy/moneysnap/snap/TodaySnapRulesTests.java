package com.ansandy.moneysnap.snap;

import java.time.LocalDate;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class TodaySnapRulesTests {

    @Test
    void acceptsUtcAndRegionIdentifiersAndRejectsOffsets() {
        assertThat(SnapTimeZones.requireRegionOrUtc("UTC")).isEqualTo(java.time.ZoneOffset.UTC);
        assertThat(SnapTimeZones.requireRegionOrUtc("Asia/Seoul").getId()).isEqualTo("Asia/Seoul");
        assertThatThrownBy(() -> SnapTimeZones.requireRegionOrUtc("+09:00"))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> SnapTimeZones.requireRegionOrUtc("GMT"))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> SnapTimeZones.requireRegionOrUtc("EST"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void totalsTodaySnapsWithoutOverflowAndRejectsAnotherDay() {
        LocalDate day = LocalDate.parse("2026-08-14");
        TodaySnapshot snapshot = TodaySnapshot.of(day, List.of(
                receipt(day, 999_999_999),
                receipt(day, 999_999_999)));
        assertThat(snapshot.totalAmountWon()).isEqualTo(1_999_999_998L);
        assertThatThrownBy(() -> TodaySnapshot.of(day, List.of(
                receipt(day.minusDays(1), 100))))
                .isInstanceOf(IllegalArgumentException.class);
    }

    private static SnapRecordReceipt receipt(LocalDate localDay, long amountWon) {
        return new SnapRecordReceipt(
                UUID.randomUUID(),
                "food",
                amountWon,
                localDay,
                Instant.parse("2026-08-13T15:30:00Z"));
    }
}
