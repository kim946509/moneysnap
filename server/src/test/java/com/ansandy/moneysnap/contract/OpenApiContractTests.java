package com.ansandy.moneysnap.contract;

import java.io.IOException;
import java.nio.file.Path;
import java.nio.file.Files;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;
import org.slf4j.LoggerFactory;

import static org.assertj.core.api.Assertions.assertThat;
import static org.junit.jupiter.api.Assumptions.assumeTrue;

class OpenApiContractTests {

	private static final Path REPOSITORY_ROOT = Path.of("..").toAbsolutePath().normalize();
	private static final Path CANONICAL_OPENAPI = REPOSITORY_ROOT.resolve("contracts/openapi/moneysnap-v1.yaml");

	@Test
	void canonicalOpenApiPassesSemanticValidation() {
		assertThat(new OpenApiContractValidator(REPOSITORY_ROOT).validate(CANONICAL_OPENAPI)).isEmpty();
	}

	@Test
	void jsonRequestWithoutAnExampleIsRejected(@TempDir Path temporaryDirectory) throws Exception {
		Path contract = temporaryDirectory.resolve("missing-example.yaml");
		Files.writeString(contract, """
				openapi: 3.1.0
				info: { title: Example, version: 1.0.0 }
				servers: [{ url: /api/v1 }]
				paths:
				  /things:
				    post:
				      operationId: createThing
				      requestBody:
				        required: true
				        content:
				          application/json:
				            schema: { type: object }
				      responses:
				        '204': { description: Created }
				""");

		assertThat(new OpenApiContractValidator(temporaryDirectory).validate(contract))
				.anyMatch(violation -> violation.contains("JSON example is required"));
	}

	@Test
	void remoteExampleIsRejected(@TempDir Path temporaryDirectory) throws Exception {
		Path contract = temporaryDirectory.resolve("remote-example.yaml");
		Files.writeString(contract, """
				openapi: 3.1.0
				info: { title: Example, version: 1.0.0 }
				servers: [{ url: /api/v1 }]
				paths:
				  /things:
				    post:
				      operationId: createThing
				      requestBody:
				        content:
				          application/json:
				            schema: { type: object }
				            examples:
				              remote: { externalValue: https://example.com/request.json }
				      responses:
				        '204': { description: Created }
				""");

		assertThat(new OpenApiContractValidator(temporaryDirectory).validate(contract))
				.anyMatch(violation -> violation.contains("HTTP example references are forbidden"));
	}

	@Test
	void invalidAuthenticationExampleIsRejectedByItsDraft202012Schema(@TempDir Path temporaryDirectory)
			throws Exception {
		Path fixture = temporaryDirectory.resolve("contracts/examples/v1/identity/session-response.json");
		Files.createDirectories(fixture.getParent());
		Files.writeString(fixture, """
				{
				  "accessToken": "access-token",
				  "accessExpiresAt": "not-a-date-time"
				}
				""");
		Path contract = temporaryDirectory.resolve("contracts/openapi/auth.yaml");
		Files.createDirectories(contract.getParent());
		Files.writeString(contract, """
				openapi: 3.1.0
				info: { title: Example, version: 1.0.0 }
				servers: [{ url: /api/v1 }]
				paths:
				  /auth:
				    post:
				      operationId: authenticate
				      responses:
				        '200':
				          description: Session
				          content:
				            application/json:
				              schema:
				                type: object
				                additionalProperties: false
				                required: [accessToken, accessExpiresAt]
				                properties:
				                  accessToken: { type: string }
				                  accessExpiresAt: { type: string, format: date-time }
				              examples:
				                canonical:
				                  externalValue: ../examples/v1/identity/session-response.json
				""");

		assertThat(new OpenApiContractValidator(temporaryDirectory).validate(contract))
				.anyMatch(violation -> violation.contains("does not match schema"));
	}

	@Test
	void errorResponseWithoutDocumentedCodesIsRejected(@TempDir Path temporaryDirectory) throws Exception {
		Path contract = temporaryDirectory.resolve("error-drift.yaml");
		Files.writeString(contract, """
				openapi: 3.1.0
				info: { title: Example, version: 1.0.0 }
				servers: [{ url: /api/v1 }]
				paths: {}
				components:
				  schemas:
				    ErrorResponse:
				      type: object
				      additionalProperties: false
				      required: [code, correlationId]
				      properties:
				        code: { type: string, enum: [] }
				        correlationId: { type: string, format: uuid }
				""");

		assertThat(new OpenApiContractValidator(temporaryDirectory).validate(contract))
				.anyMatch(violation -> violation.contains("code enum must not be empty"));
	}

	@Test
	void unresolvedReferenceIsRejected(@TempDir Path temporaryDirectory) throws Exception {
		Path contract = temporaryDirectory.resolve("unresolved-ref.yaml");
		Files.writeString(contract, """
				openapi: 3.1.0
				info: { title: Example, version: 1.0.0 }
				servers: [{ url: /api/v1 }]
				paths:
				  /things:
				    get:
				      operationId: listThings
				      responses:
				        '200':
				          description: Things
				          content:
				            application/json:
				              schema: { $ref: '#/components/schemas/Missing' }
				              examples:
				                canonical: { externalValue: ../examples/v1/things.json }
				""");

		Logger referenceLogger = (Logger) LoggerFactory.getLogger(
				"io.swagger.v3.parser.reference.ReferenceVisitor");
		Level previousLevel = referenceLogger.getLevel();
		try {
			referenceLogger.setLevel(Level.OFF);
			assertThat(new OpenApiContractValidator(temporaryDirectory).validate(contract))
					.anyMatch(violation -> violation.toLowerCase().contains("missing"));
		}
		finally {
			referenceLogger.setLevel(previousLevel);
		}
	}

	@Test
	void exampleSymlinkCannotEscapeTheCanonicalFixtureDirectory(@TempDir Path temporaryDirectory)
			throws Exception {
		Path fixtureRoot = temporaryDirectory.resolve("contracts/examples/v1/identity");
		Files.createDirectories(fixtureRoot);
		Path outside = temporaryDirectory.resolve("outside.json");
		Files.writeString(outside, "{\"value\":\"escaped\"}");
		try {
			Files.createSymbolicLink(fixtureRoot.resolve("escaped.json"), outside);
		}
		catch (UnsupportedOperationException | IOException | SecurityException exception) {
			assumeTrue(false, "Symbolic links are unavailable: " + exception.getMessage());
		}

		Path contract = temporaryDirectory.resolve("contracts/openapi/escaped-example.yaml");
		Files.createDirectories(contract.getParent());
		Files.writeString(contract, """
				openapi: 3.1.0
				info: { title: Example, version: 1.0.0 }
				servers: [{ url: /api/v1 }]
				paths:
				  /things:
				    post:
				      operationId: createThing
				      requestBody:
				        content:
				          application/json:
				            schema: { type: object }
				            examples:
				              escaped: { externalValue: ../examples/v1/identity/escaped.json }
				      responses: { '204': { description: Done } }
				""");

		assertThat(new OpenApiContractValidator(temporaryDirectory).validate(contract))
				.anyMatch(violation -> violation.contains("resolve inside contracts/examples/v1"));
	}

	@Test
	void duplicateOperationIdIsRejected(@TempDir Path temporaryDirectory) throws Exception {
		Path contract = temporaryDirectory.resolve("duplicate-operation.yaml");
		Files.writeString(contract, """
				openapi: 3.1.0
				info: { title: Example, version: 1.0.0 }
				servers: [{ url: /api/v1 }]
				paths:
				  /things:
				    get:
				      operationId: repeatedOperation
				      responses: { '204': { description: Done } }
				  /other-things:
				    get:
				      operationId: repeatedOperation
				      responses: { '204': { description: Done } }
				""");

		assertThat(new OpenApiContractValidator(temporaryDirectory).validate(contract))
				.anyMatch(violation -> violation.contains("Duplicate operation ID"));
	}

	@Test
	void syntheticSnapExampleUsesTheSameDraft202012ValidationSeam(@TempDir Path temporaryDirectory)
			throws Exception {
		Path fixture = temporaryDirectory.resolve("contracts/examples/v1/snap/create-request.json");
		Files.createDirectories(fixture.getParent());
		Files.writeString(fixture, "{\"amountWon\":0}");
		Path contract = temporaryDirectory.resolve("contracts/openapi/snap.yaml");
		Files.createDirectories(contract.getParent());
		Files.writeString(contract, """
				openapi: 3.1.0
				info: { title: Example, version: 1.0.0 }
				servers: [{ url: /api/v1 }]
				paths:
				  /snaps:
				    post:
				      operationId: createSnap
				      requestBody:
				        content:
				          application/json:
				            schema:
				              type: object
				              required: [amountWon]
				              properties:
				                amountWon: { type: integer, minimum: 1 }
				            examples:
				              canonical: { externalValue: ../examples/v1/snap/create-request.json }
				      responses: { '204': { description: Created } }
				""");

		assertThat(new OpenApiContractValidator(temporaryDirectory).validate(contract))
				.anyMatch(violation -> violation.contains("does not match schema"));
	}
}
