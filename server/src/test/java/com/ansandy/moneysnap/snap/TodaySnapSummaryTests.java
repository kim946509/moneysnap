package com.ansandy.moneysnap.snap;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.time.LocalDate;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class TodaySnapSummaryTests {

    private static final LocalDate JUNE_THIRD = LocalDate.of(2026, 6, 3);

    @Test
    void moneyAcceptsOnlyPositiveKrwIntegers() {
        assertThat(new KrwAmount(1).value()).isEqualTo(1);
        assertThatThrownBy(() -> new KrwAmount(0))
            .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new KrwAmount(-1))
            .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void categoriesExposeTheEightCanonicalCodes() {
        assertThat(Arrays.stream(SnapCategory.values()).map(SnapCategory::code))
            .containsExactly(
                "food",
                "cafe",
                "transportation",
                "shopping",
                "living",
                "culture",
                "health",
                "other"
            );
    }

    @Test
    void totalIncludesEveryEntryForTheDay() {
        var summary = new TodaySnapSummary(
            JUNE_THIRD,
            List.of(
                entry(18_900, SnapCategory.FOOD),
                entry(5_200, SnapCategory.CAFE),
                entry(2_800, SnapCategory.TRANSPORTATION),
                entry(16_300, SnapCategory.LIVING)
            )
        );

        assertThat(summary.totalAmount()).isEqualTo(43_200);
    }

    @Test
    void anEmptyDayHasAZeroTotal() {
        var summary = new TodaySnapSummary(JUNE_THIRD, List.of());

        assertThat(summary.totalAmount()).isZero();
    }

    @Test
    void rejectsAnEntryRecordedOnAnotherDay() {
        var tomorrow = new TodaySnapEntry(
            UUID.randomUUID(),
            JUNE_THIRD.plusDays(1),
            SnapCategory.OTHER,
            new KrwAmount(1_000)
        );

        assertThatThrownBy(() -> new TodaySnapSummary(JUNE_THIRD, List.of(tomorrow)))
            .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void totalsMultipleMaximumSnapAmountsWithoutOverflow() {
        var summary = new TodaySnapSummary(
            JUNE_THIRD,
            List.of(
                entry(999_999_999, SnapCategory.FOOD),
                entry(999_999_999, SnapCategory.CAFE)
            )
        );

        assertThat(summary.totalAmount()).isEqualTo(1_999_999_998L);
    }

    private TodaySnapEntry entry(long amount, SnapCategory category) {
        return new TodaySnapEntry(
            UUID.randomUUID(),
            JUNE_THIRD,
            category,
            new KrwAmount(amount)
        );
    }
}
