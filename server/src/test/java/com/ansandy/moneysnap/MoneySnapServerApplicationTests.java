package com.ansandy.moneysnap;

import javax.sql.DataSource;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.hamcrest.Matchers.containsString;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@SpringBootTest(properties = {
		"spring.autoconfigure.exclude="
				+ "org.springframework.boot.jdbc.autoconfigure.DataSourceAutoConfiguration,"
				+ "org.springframework.boot.flyway.autoconfigure.FlywayAutoConfiguration"
})
class MoneySnapServerApplicationTests {

	@Autowired
	private MockMvc mockMvc;

	@MockitoBean
	private DataSource dataSource;

	@Test
	void healthIsAvailableWithoutExposingInternalDetails() throws Exception {
		mockMvc.perform(get("/actuator/health"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("UP"))
				.andExpect(jsonPath("$.components").doesNotExist())
				.andExpect(content().string(not(containsString("jdbc"))))
				.andExpect(content().string(not(containsString("sqlite"))))
				.andExpect(content().string(not(containsString("moneysnap.db"))));
	}

	@Test
	void rootReportsServiceAvailabilityWithoutInfrastructureDetails() throws Exception {
		mockMvc.perform(get("/"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.service").value("moneysnap-api"))
				.andExpect(jsonPath("$.status").value("UP"))
				.andExpect(jsonPath("$.components").doesNotExist())
				.andExpect(content().string(not(containsString("jdbc"))))
				.andExpect(content().string(not(containsString("sqlite"))))
				.andExpect(content().string(not(containsString("moneysnap.db"))));
	}

	@Test
	void prometheusMetricsAreAvailableToTheMonitoringNetwork() throws Exception {
		mockMvc.perform(get("/actuator/prometheus"))
				.andExpect(status().isOk())
				.andExpect(content().string(containsString("process_uptime_seconds")));
	}

	@Test
	void unauthenticatedUnknownRoutesAreRejected() throws Exception {
		mockMvc.perform(get("/v1"))
				.andExpect(status().isUnauthorized());
	}

}
