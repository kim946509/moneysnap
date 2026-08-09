package com.ansandy.moneysnap;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@SpringBootTest(properties = {
		"spring.autoconfigure.exclude="
				+ "org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration,"
				+ "org.springframework.boot.flyway.autoconfigure.FlywayAutoConfiguration",
		"NEON_RUNTIME_DATABASE_URL=jdbc:postgresql://runtime.invalid/moneysnap",
		"NEON_RUNTIME_DATABASE_USERNAME=runtime-test",
		"NEON_RUNTIME_DATABASE_PASSWORD=runtime-test-password",
		"NEON_MIGRATION_DATABASE_URL=jdbc:postgresql://migration.invalid/moneysnap",
		"NEON_MIGRATION_DATABASE_USERNAME=migration-test",
		"NEON_MIGRATION_DATABASE_PASSWORD=migration-test-password"
})
class MoneySnapServerApplicationTests {

	@Autowired
	private MockMvc mockMvc;

	@Test
	void healthIsAvailableWithoutExposingInternalDetails() throws Exception {
		mockMvc.perform(get("/actuator/health"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("UP"))
				.andExpect(jsonPath("$.components").doesNotExist());
	}

	@Test
	void routesAreDeniedUntilAnAuthenticationPolicyIsImplemented() throws Exception {
		mockMvc.perform(get("/v1"))
				.andExpect(status().isForbidden());
	}

}
