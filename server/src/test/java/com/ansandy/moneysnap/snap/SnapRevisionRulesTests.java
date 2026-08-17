package com.ansandy.moneysnap.snap;

import java.util.UUID;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class SnapRevisionRulesTests {

    @Test
    void fingerprintsNormalizedReviseAndDeletePayloads() {
        UUID snapId = UUID.fromString("018f1e2d-1234-7abc-8def-0123456789ab");
        SnapReviseCommand original = new SnapReviseCommand(
                "revise-key", 1, SnapCategory.CAFE, new KrwAmount(5_200));
        SnapReviseCommand samePayload = new SnapReviseCommand(
                "other-key", 1, SnapCategory.CAFE, new KrwAmount(5_200));
        SnapReviseCommand differentVersion = new SnapReviseCommand(
                "revise-key", 2, SnapCategory.CAFE, new KrwAmount(5_200));

        assertThat(samePayload.fingerprint(snapId)).isEqualTo(original.fingerprint(snapId));
        assertThat(differentVersion.fingerprint(snapId)).isNotEqualTo(original.fingerprint(snapId));
        assertThat(new SnapDeleteCommand("delete-key", snapId).fingerprint())
                .isNotEqualTo(new SnapDeleteCommand("delete-key", UUID.randomUUID()).fingerprint());
    }

    @Test
    void rejectsNonPositiveExpectedVersionAndBlankMutationKeys() {
        assertThatThrownBy(() -> new SnapReviseCommand(
                "revise-key", 0, SnapCategory.FOOD, new KrwAmount(1)))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new SnapDeleteCommand(" ", UUID.randomUUID()))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
