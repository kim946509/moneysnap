package com.ansandy.moneysnap.group;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class GroupNameTests {

    @Test
    void trimsAndCountsGraphemeClustersNotUtf16Units() {
        assertThat(new GroupName("  가족  ").value()).isEqualTo("가족");
        assertThat(new GroupName("👨‍👩‍👧‍👦".repeat(30)).value()).hasSizeGreaterThan(30);
        assertThatThrownBy(() -> new GroupName(" "))
                .isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> new GroupName("👨‍👩‍👧‍👦".repeat(31)))
                .isInstanceOf(IllegalArgumentException.class);
    }
}
