package com.ansandy.moneysnap.media;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MediaConfigurationTests {

	@Test
	void disabledR2KeepsTheInProcessStore() {
		assertThat(MediaConfiguration.selectStore(false, "", "", "", "")).isInstanceOf(MemoryObjectStore.class);
	}

	@Test
	void enabledR2WithoutCredentialsFailsClosed() {
		assertThatThrownBy(() -> MediaConfiguration.selectStore(true, "https://example.r2.cloudflarestorage.com", "bucket", "", "secret"))
				.isInstanceOf(IllegalStateException.class)
				.hasMessageContaining("credentials");
	}
}
