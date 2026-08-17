package com.ansandy.moneysnap.contract;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

import com.jayway.jsonpath.Configuration;

import static org.assertj.core.api.Assertions.assertThat;

public final class CanonicalIdentityExamples {

	private static final Path ROOT = Path.of("..").toAbsolutePath().normalize()
			.resolve("contracts/examples/v1/identity");

	private CanonicalIdentityExamples() {
	}

	public static String json(String fileName) {
		Path fixture = ROOT.resolve(fileName).normalize();
		if (!fixture.startsWith(ROOT)) {
			throw new IllegalArgumentException("Fixture must stay inside canonical identity examples");
		}
		try {
			return Files.readString(fixture);
		}
		catch (IOException exception) {
			throw new IllegalStateException("Cannot read canonical identity example " + fileName, exception);
		}
	}

	private static Set<String> fieldNames(String fileName) {
		return fieldNamesOfJson(json(fileName));
	}

	public static String jsonWithStringProperty(String fileName, String property, String value) {
		Object fixture = Configuration.defaultConfiguration().jsonProvider().parse(json(fileName));
		if (!(fixture instanceof Map<?, ?> object)) {
			throw new IllegalArgumentException("Identity HTTP request must be a JSON object");
		}
		Map<String, Object> extended = new LinkedHashMap<>();
		object.forEach((key, fieldValue) -> extended.put(String.valueOf(key), fieldValue));
		extended.put(property, value);
		return Configuration.defaultConfiguration().jsonProvider().toJson(extended);
	}

	private static Set<String> fieldNamesOfJson(String json) {
		Object fixture = Configuration.defaultConfiguration().jsonProvider().parse(json);
		if (!(fixture instanceof Map<?, ?> object)) {
			throw new IllegalArgumentException("Identity HTTP response must be a JSON object");
		}
		return object.keySet().stream().map(String::valueOf).collect(java.util.stream.Collectors.toSet());
	}

	public static void assertExactResponse(String actualJson, String fixtureName) {
		assertThat(fieldNamesOfJson(actualJson)).containsExactlyInAnyOrderElementsOf(fieldNames(fixtureName));
		Object actual = Configuration.defaultConfiguration().jsonProvider().parse(actualJson);
		Object expected = Configuration.defaultConfiguration().jsonProvider().parse(json(fixtureName));
		if (actual instanceof Map<?, ?> actualObject && expected instanceof Map<?, ?> expectedObject
				&& expectedObject.containsKey("code")) {
			assertThat(actualObject.get("code")).isEqualTo(expectedObject.get("code"));
		}
	}
}
