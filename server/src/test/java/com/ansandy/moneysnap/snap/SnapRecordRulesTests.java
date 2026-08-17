package com.ansandy.moneysnap.snap;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.util.List;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SnapRecordRulesTests {

    private static final Clock CLOCK = Clock.fixed(
            Instant.parse("2026-08-13T15:30:00Z"), ZoneOffset.UTC);

    @Test
    void acceptsTheKrwAmountBounds() {
        assertThat(new KrwAmount(1).value()).isEqualTo(1);
        assertThat(new KrwAmount(999_999_999).value()).isEqualTo(999_999_999);
    }

    @Test
    void rejectsKrwAmountsOutsideTheBounds() {
        assertThatThrownBy(() -> new KrwAmount(0)).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new KrwAmount(1_000_000_000)).isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void decodesExactlyTheEightLowercaseCategories() {
        assertThat(List.of(
                "food", "cafe", "transportation", "shopping",
                "living", "culture", "health", "other"))
                .allSatisfy(code -> assertThat(SnapCategory.fromCode(code).code()).isEqualTo(code));
        assertThatThrownBy(() -> SnapCategory.fromCode("FOOD"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void acceptsCurrentAndPreviousLocalDayInTheSubmittedRegion() {
        assertThatCode(() -> command(LocalDate.parse("2026-08-14"), "Asia/Seoul").validateLocalDay(CLOCK))
                .doesNotThrowAnyException();
        assertThatCode(() -> command(LocalDate.parse("2026-08-13"), "Asia/Seoul").validateLocalDay(CLOCK))
                .doesNotThrowAnyException();
        assertThatCode(() -> command(LocalDate.parse("2026-08-13"), "UTC").validateLocalDay(CLOCK))
                .doesNotThrowAnyException();
        assertThatCode(() -> command(LocalDate.parse("2026-08-12"), "UTC").validateLocalDay(CLOCK))
                .doesNotThrowAnyException();
    }

    @Test
    void rejectsOffsetsShortAliasesFutureAndTwoDaysAgo() {
        assertThatThrownBy(() -> command(LocalDate.parse("2026-08-14"), "+09:00").validateLocalDay(CLOCK))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> command(LocalDate.parse("2026-08-14"), "EST").validateLocalDay(CLOCK))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> command(LocalDate.parse("2026-08-14"), "GMT").validateLocalDay(CLOCK))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> command(LocalDate.parse("2026-08-14"), "KST").validateLocalDay(CLOCK))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> command(LocalDate.parse("2026-08-14"), "PST").validateLocalDay(CLOCK))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> command(LocalDate.parse("2026-08-14"), "Mars/Olympus").validateLocalDay(CLOCK))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> command(LocalDate.parse("2026-08-15"), "Asia/Seoul").validateLocalDay(CLOCK))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> command(LocalDate.parse("2026-08-12"), "Asia/Seoul").validateLocalDay(CLOCK))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void fingerprintsTheNormalizedSemanticPayload() {
        SnapRecordCommand original = command(LocalDate.parse("2026-08-14"), "Asia/Seoul");
        SnapRecordCommand retry = new SnapRecordCommand(
                "another-mutation-key",
                original.localDay(),
                original.timeZone(),
                original.category(),
                original.amount(),
                null);
        SnapRecordCommand changedAmount = new SnapRecordCommand(
                "mutation-key",
                original.localDay(),
                original.timeZone(),
                original.category(),
                new KrwAmount(18_901),
                null);

        assertThat(retry.fingerprint()).isEqualTo(original.fingerprint());
        assertThat(changedAmount.fingerprint()).isNotEqualTo(original.fingerprint());
        SnapRecordCommand compatibilityExample = command(LocalDate.parse("2026-08-13"), "Asia/Seoul");
        assertThat(compatibilityExample.fingerprint())
                .isEqualTo("b84f3f06e987926ecfdb3c635e6c15a1b2d6690a23e280e02fd8dea7e490123c");
    }

    @Test
    void validatesTheOpaqueMutationKeyWithoutRequiringUuidSyntax() {
        assertThatCode(() -> command(LocalDate.parse("2026-08-14"), "Asia/Seoul"))
                .doesNotThrowAnyException();
        assertThatThrownBy(() -> new SnapRecordCommand(
                " ", LocalDate.parse("2026-08-14"), "Asia/Seoul",
                SnapCategory.FOOD, new KrwAmount(1), null))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new SnapRecordCommand(
                "x".repeat(129), LocalDate.parse("2026-08-14"), "Asia/Seoul",
                SnapCategory.FOOD, new KrwAmount(1), null))
                .isInstanceOf(IllegalArgumentException.class);
    }

    private static SnapRecordCommand command(LocalDate localDay, String timeZone) {
        return new SnapRecordCommand(
                "mutation-key", localDay, timeZone,
                SnapCategory.FOOD, new KrwAmount(18_900), null);
    }
}
