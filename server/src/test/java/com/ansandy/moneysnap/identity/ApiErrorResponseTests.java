package com.ansandy.moneysnap.identity;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;

import static org.assertj.core.api.Assertions.assertThat;

@ExtendWith(OutputCaptureExtension.class)
class ApiErrorResponseTests {

	@Test
	void logsTheSameSafeCorrelationIdReturnedToTheClient(CapturedOutput output) {
		ApiErrorResponse response = ApiErrorResponse.of(ApiErrorCode.SESSION_REJECTED);

		assertThat(output)
				.contains("code=SESSION_REJECTED")
				.contains("correlationId=" + response.correlationId());
	}
}
