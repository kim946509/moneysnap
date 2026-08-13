package com.ansandy.moneysnap.identity;

import java.nio.file.Path;
import java.util.Arrays;
import java.util.Set;

import io.swagger.v3.parser.OpenAPIV3Parser;
import io.swagger.v3.parser.core.models.ParseOptions;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;

import static org.assertj.core.api.Assertions.assertThat;

@ExtendWith(OutputCaptureExtension.class)
class ApiErrorResponseTests {

	@Test
	void documentsEveryRuntimeErrorCodeInTheCanonicalOpenApi() throws Exception {
		ParseOptions options = new ParseOptions();
		options.setResolve(true);
		var openApi = new OpenAPIV3Parser()
				.readLocation(Path.of("..", "contracts", "openapi", "moneysnap-v1.yaml")
						.toAbsolutePath().normalize().toString(), null, options)
				.getOpenAPI();
		var errorSchema = openApi.getComponents().getSchemas().get("ErrorResponse");
		var codeSchema = (io.swagger.v3.oas.models.media.Schema<?>) errorSchema.getProperties().get("code");
		var documented = codeSchema.getEnum().stream()
				.map(String::valueOf)
				.collect(java.util.stream.Collectors.toSet());
		Set<String> runtimeCodes = Arrays.stream(ApiErrorCode.values())
				.map(Enum::name)
				.collect(java.util.stream.Collectors.toSet());

		assertThat(documented).isEqualTo(runtimeCodes);
	}

	@Test
	void logsTheSameSafeCorrelationIdReturnedToTheClient(CapturedOutput output) {
		ApiErrorResponse response = ApiErrorResponse.of(ApiErrorCode.SESSION_REJECTED);

		assertThat(output)
				.contains("code=SESSION_REJECTED")
				.contains("correlationId=" + response.correlationId());
	}
}
