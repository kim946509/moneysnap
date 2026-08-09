package com.ansandy.moneysnap;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

import org.junit.jupiter.api.Test;

import static org.assertj.core.api.Assertions.assertThat;

class NeonConfigurationContractTests {

	@Test
	void runtimeAndMigrationConnectionsRequireSeparateNeonVariables() throws IOException {
		Properties properties = new Properties();
		try (InputStream input = getClass().getResourceAsStream("/application.properties")) {
			assertThat(input).isNotNull();
			properties.load(input);
		}

		assertThat(properties)
				.containsEntry("spring.datasource.url", "${NEON_RUNTIME_DATABASE_URL}")
				.containsEntry("spring.datasource.username", "${NEON_RUNTIME_DATABASE_USERNAME}")
				.containsEntry("spring.datasource.password", "${NEON_RUNTIME_DATABASE_PASSWORD}")
				.containsEntry("spring.flyway.url", "${NEON_MIGRATION_DATABASE_URL}")
				.containsEntry("spring.flyway.user", "${NEON_MIGRATION_DATABASE_USERNAME}")
				.containsEntry("spring.flyway.password", "${NEON_MIGRATION_DATABASE_PASSWORD}");
	}
}
