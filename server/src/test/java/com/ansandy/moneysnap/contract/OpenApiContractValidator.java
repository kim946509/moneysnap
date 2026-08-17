package com.ansandy.moneysnap.contract;

import java.io.IOException;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Map;
import java.util.Set;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.networknt.schema.InputFormat;
import com.networknt.schema.SchemaRegistry;
import com.networknt.schema.SpecificationVersion;
import io.swagger.v3.parser.OpenAPIV3Parser;
import io.swagger.v3.core.util.Json31;
import io.swagger.v3.oas.models.OpenAPI;
import io.swagger.v3.oas.models.Operation;
import io.swagger.v3.oas.models.examples.Example;
import io.swagger.v3.oas.models.media.Content;
import io.swagger.v3.oas.models.media.MediaType;
import io.swagger.v3.oas.models.responses.ApiResponse;
import io.swagger.v3.oas.models.servers.Server;
import io.swagger.v3.parser.core.models.ParseOptions;
import io.swagger.v3.parser.core.models.SwaggerParseResult;

final class OpenApiContractValidator {

	private final Path repositoryRoot;

	OpenApiContractValidator(Path repositoryRoot) {
		this.repositoryRoot = repositoryRoot.toAbsolutePath().normalize();
	}

	List<String> validate(Path contract) {
		List<String> violations = new ArrayList<>();
		Path canonicalContract = requireRepositoryPath(contract, "OpenAPI contract", violations);
		if (canonicalContract == null) {
			return violations;
		}

		ParseOptions options = new ParseOptions();
		options.setResolve(true);
		SwaggerParseResult result = new OpenAPIV3Parser()
				.readLocation(canonicalContract.toString(), null, options);
		if (result.getMessages() != null) {
			violations.addAll(result.getMessages());
		}
		OpenAPI openApi = result.getOpenAPI();
		if (openApi == null) {
			violations.add("OpenAPI document could not be parsed");
			return violations;
		}

		validateServerBase(openApi, violations);
		validateOperationIds(openApi, violations);
		validateJsonExamples(openApi, canonicalContract, violations);
		validateErrorResponse(openApi, violations);
		return violations;
	}

	private static void validateServerBase(OpenAPI openApi, List<String> violations) {
		List<String> serverUrls = openApi.getServers() == null
				? List.of()
				: openApi.getServers().stream().map(Server::getUrl).toList();
		if (!serverUrls.equals(List.of("/api/v1"))) {
			violations.add("Canonical server URL must be exactly /api/v1");
		}
	}

	private static void validateOperationIds(OpenAPI openApi, List<String> violations) {
		if (openApi.getPaths() == null) {
			violations.add("OpenAPI paths are required");
			return;
		}
		Set<String> operationIds = new HashSet<>();
		openApi.getPaths().forEach((path, pathItem) -> {
			for (Operation operation : pathItem.readOperations()) {
				String operationId = operation.getOperationId();
				if (operationId == null || operationId.isBlank()) {
					violations.add("Operation ID is required for " + path);
				}
				else if (!operationIds.add(operationId)) {
					violations.add("Duplicate operation ID: " + operationId);
				}
			}
		});
	}

	private void validateJsonExamples(OpenAPI openApi, Path contract, List<String> violations) {
		if (openApi.getPaths() == null) {
			return;
		}
		openApi.getPaths().forEach((path, pathItem) -> pathItem.readOperationsMap()
				.forEach((method, operation) -> {
					if (operation.getRequestBody() != null) {
						validateContentExamples(openApi, operation.getRequestBody().getContent(),
								method + " " + path + " request", contract, violations);
					}
					if (operation.getResponses() != null) {
						operation.getResponses().forEach((status, response) -> {
							ApiResponse resolved = resolveResponse(openApi, response);
							validateContentExamples(openApi, resolved == null ? null : resolved.getContent(),
									method + " " + path + " response " + status, contract, violations);
						});
					}
				}));
	}

	private static ApiResponse resolveResponse(OpenAPI openApi, ApiResponse response) {
		if (response == null || response.get$ref() == null) {
			return response;
		}
		String prefix = "#/components/responses/";
		if (!response.get$ref().startsWith(prefix) || openApi.getComponents() == null
				|| openApi.getComponents().getResponses() == null) {
			return response;
		}
		return openApi.getComponents().getResponses().get(response.get$ref().substring(prefix.length()));
	}

	private void validateContentExamples(
			OpenAPI openApi,
			Content content,
			String location,
			Path contract,
			List<String> violations) {
		if (content == null || !content.containsKey("application/json")) {
			return;
		}
		MediaType mediaType = content.get("application/json");
		boolean hasExample = mediaType != null && (mediaType.getExample() != null
				|| mediaType.getExamples() != null && !mediaType.getExamples().isEmpty());
		if (!hasExample) {
			violations.add("JSON example is required for " + location);
			return;
		}
		if (mediaType.getExample() != null) {
			violations.add("JSON examples must use canonical external fixtures for " + location);
		}
		if (mediaType.getExamples() != null) {
			mediaType.getExamples().forEach((name, example) ->
					validateExternalExample(openApi, mediaType.getSchema(), example, contract,
							location + " example " + name, violations));
		}
	}

	private void validateExternalExample(
			OpenAPI openApi,
			io.swagger.v3.oas.models.media.Schema<?> schema,
			Example example,
			Path contract,
			String location,
			List<String> violations) {
		String externalValue = example == null ? null : example.getExternalValue();
		if (externalValue == null || externalValue.isBlank()) {
			violations.add("JSON examples must use canonical external fixtures for " + location);
			return;
		}
		try {
			URI uri = URI.create(externalValue);
			if ("http".equalsIgnoreCase(uri.getScheme()) || "https".equalsIgnoreCase(uri.getScheme())) {
				violations.add("HTTP example references are forbidden for " + location);
				return;
			}
			if (uri.isAbsolute() || externalValue.startsWith("//")) {
				violations.add("Example reference must be repository-relative for " + location);
				return;
			}
			Path fixture = contract.getParent().resolve(externalValue).normalize();
			Path fixtureRoot = repositoryRoot.resolve("contracts/examples/v1").normalize();
			if (!fixture.startsWith(fixtureRoot)) {
				violations.add("Example reference must stay inside contracts/examples/v1 for " + location);
			}
			else if (!Files.isRegularFile(fixture)) {
				violations.add("Example fixture does not exist for " + location + ": " + externalValue);
			}
			else {
				Path realRepositoryRoot = repositoryRoot.toRealPath();
				Path realFixtureRoot = fixtureRoot.toRealPath();
				Path realFixture = fixture.toRealPath();
				if (!realFixtureRoot.startsWith(realRepositoryRoot)
						|| !realFixture.startsWith(realFixtureRoot)) {
					violations.add("Example reference must resolve inside contracts/examples/v1 for " + location);
				}
				else {
					validateFixture(openApi, schema, realFixture, location, violations);
				}
			}
		}
		catch (IllegalArgumentException | IOException exception) {
			violations.add("Invalid example reference for " + location + ": " + externalValue);
		}
	}

	private static void validateFixture(
			OpenAPI openApi,
			io.swagger.v3.oas.models.media.Schema<?> schema,
			Path fixture,
			String location,
			List<String> violations) {
		if (schema == null) {
			violations.add("JSON schema is required for " + location);
			return;
		}
		try {
			SchemaRegistry registry = SchemaRegistry.withDefaultDialect(SpecificationVersion.DRAFT_2020_12);
			com.networknt.schema.Schema compiled = registry.getSchema(
					jsonSchemaDocument(openApi, schema), InputFormat.JSON);
			compiled.validate(Files.readString(fixture), InputFormat.JSON,
					context -> context.executionConfig(config -> config.formatAssertionsEnabled(true)))
					.forEach(error -> violations.add(
							"Example does not match schema for " + location + ": " + error.getMessage()));
		}
		catch (Exception exception) {
			violations.add("Example validation failed for " + location + ": " + exception.getMessage());
		}
	}

	private static String jsonSchemaDocument(
			OpenAPI openApi,
			io.swagger.v3.oas.models.media.Schema<?> schema) {
		ObjectNode document = Json31.mapper().createObjectNode();
		document.put("$schema", SpecificationVersion.DRAFT_2020_12.getDialectId());
		JsonNode root = Json31.mapper().valueToTree(schema);
		if (root instanceof ObjectNode rootObject) {
			document.setAll(rootObject);
		}
		ObjectNode definitions = Json31.mapper().createObjectNode();
		if (openApi.getComponents() != null && openApi.getComponents().getSchemas() != null) {
			openApi.getComponents().getSchemas().forEach(
					(name, component) -> definitions.set(name, Json31.mapper().valueToTree(component)));
		}
		document.set("$defs", definitions);
		rewriteComponentReferences(document);
		return document.toString();
	}

	private static void rewriteComponentReferences(JsonNode node) {
		if (node instanceof ObjectNode object) {
			JsonNode reference = object.get("$ref");
			String prefix = "#/components/schemas/";
			if (reference != null && reference.isTextual() && reference.textValue().startsWith(prefix)) {
				object.put("$ref", "#/$defs/" + reference.textValue().substring(prefix.length()));
			}
			Iterator<Map.Entry<String, JsonNode>> fields = object.fields();
			while (fields.hasNext()) {
				rewriteComponentReferences(fields.next().getValue());
			}
		}
		else if (node.isArray()) {
			node.forEach(OpenApiContractValidator::rewriteComponentReferences);
		}
	}

	private static void validateErrorResponse(OpenAPI openApi, List<String> violations) {
		io.swagger.v3.oas.models.media.Schema<?> error = openApi.getComponents() == null
				|| openApi.getComponents().getSchemas() == null
				? null
				: openApi.getComponents().getSchemas().get("ErrorResponse");
		if (error == null) {
			violations.add("ErrorResponse schema is required");
			return;
		}
		Set<String> exactFields = Set.of("code", "correlationId");
		Set<String> properties = error.getProperties() == null
				? Set.of()
				: error.getProperties().keySet();
		Set<String> required = error.getRequired() == null
				? Set.of()
				: Set.copyOf(error.getRequired());
		if (!properties.equals(exactFields) || !required.equals(exactFields)
				|| !Boolean.FALSE.equals(error.getAdditionalProperties())) {
			violations.add("ErrorResponse must require exactly code and correlationId with no additional properties");
		}

		io.swagger.v3.oas.models.media.Schema<?> code = error.getProperties() == null
				? null
				: error.getProperties().get("code");
		Set<String> documentedCodes = code == null || code.getEnum() == null
				? Set.of()
				: code.getEnum().stream().map(String::valueOf).collect(java.util.stream.Collectors.toSet());
		if (documentedCodes.isEmpty()) {
			violations.add("ErrorResponse code enum must not be empty");
		}

		io.swagger.v3.oas.models.media.Schema<?> correlationId = error.getProperties() == null
				? null
				: error.getProperties().get("correlationId");
		if (correlationId == null || !"uuid".equals(correlationId.getFormat())) {
			violations.add("ErrorResponse correlationId must use uuid format");
		}
	}

	private Path requireRepositoryPath(Path path, String label, List<String> violations) {
		Path normalized = path.toAbsolutePath().normalize();
		if (!normalized.startsWith(repositoryRoot)) {
			violations.add(label + " must stay inside the repository");
			return null;
		}
		return normalized;
	}
}
