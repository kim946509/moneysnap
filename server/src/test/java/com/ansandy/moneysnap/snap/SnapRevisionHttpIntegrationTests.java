package com.ansandy.moneysnap.snap;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.HexFormat;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@Testcontainers
@AutoConfigureMockMvc
@SpringBootTest
class SnapRevisionHttpIntegrationTests {

    private static final Instant NOW = Instant.parse("2026-08-13T15:30:00Z");

    @Container
    private static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(
            DockerImageName.parse("postgres:18-alpine"));

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcClient jdbc;

    @MockitoBean(name = "identityClock")
    private Clock clock;

    @DynamicPropertySource
    static void databaseProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", POSTGRES::getJdbcUrl);
        registry.add("spring.datasource.username", POSTGRES::getUsername);
        registry.add("spring.datasource.password", POSTGRES::getPassword);
        registry.add("spring.flyway.url", POSTGRES::getJdbcUrl);
        registry.add("spring.flyway.user", POSTGRES::getUsername);
        registry.add("spring.flyway.password", POSTGRES::getPassword);
    }

    @BeforeEach
    void resetDatabase() {
        given(clock.instant()).willReturn(NOW);
        jdbc.sql("TRUNCATE TABLE snap_delete_mutations, snap_revise_mutations, snap_record_mutations, snaps, "
                + "identity_refresh_tokens, identity_sessions, apple_identities, users CASCADE").update();
    }

    @Test
    void ownerCanReadReviseAndDeleteTheirSnap() throws Exception {
        String accessToken = signIn("owner");
        String snapId = record(accessToken, "record-1", "food", 18_900);

        MvcResult detail = mockMvc.perform(get("/api/v1/snaps/" + snapId)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.category").value("food"))
                .andExpect(jsonPath("$.amountWon").value(18_900))
                .andExpect(jsonPath("$.localDay").value("2026-08-14"))
                .andExpect(jsonPath("$.version").value(1))
                .andReturn();
        Map<String, Object> detailBody = JsonPath.parse(detail.getResponse().getContentAsString()).read("$");
        assertThat(detailBody.keySet()).isEqualTo(Set.of(
                "id", "category", "amountWon", "localDay", "createdAt", "updatedAt", "version"));

        given(clock.instant()).willReturn(NOW.plusSeconds(60));
        MvcResult revised = mockMvc.perform(patch("/api/v1/snaps/" + snapId)
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content(revise("revise-1", 1, "cafe", 5_200)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.category").value("cafe"))
                .andExpect(jsonPath("$.amountWon").value(5_200))
                .andExpect(jsonPath("$.localDay").value("2026-08-14"))
                .andExpect(jsonPath("$.createdAt").value("2026-08-13T15:30:00Z"))
                .andExpect(jsonPath("$.updatedAt").value("2026-08-13T15:31:00Z"))
                .andExpect(jsonPath("$.version").value(2))
                .andReturn();
        mockMvc.perform(patch("/api/v1/snaps/" + snapId)
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content(revise("revise-1", 1, "cafe", 5_200)))
                .andExpect(status().isOk())
                .andExpect(result -> assertThat(result.getResponse().getContentAsString())
                        .isEqualTo(revised.getResponse().getContentAsString()));

        mockMvc.perform(delete("/api/v1/snaps/" + snapId)
                        .header("Authorization", "Bearer " + accessToken)
                        .header("X-Client-Mutation-Id", "delete-1"))
                .andExpect(status().isNoContent());
        mockMvc.perform(delete("/api/v1/snaps/" + snapId)
                        .header("Authorization", "Bearer " + accessToken)
                        .header("X-Client-Mutation-Id", "delete-1"))
                .andExpect(status().isNoContent());
        mockMvc.perform(get("/api/v1/snaps/" + snapId)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_ACCESSIBLE"));
        today(accessToken).andExpect(jsonPath("$.snaps.length()").value(0));
    }

    @Test
    void hidesForeignAndUnknownSnapsBehindTheSameNotAccessibleContract() throws Exception {
        String owner = signIn("detail-owner");
        String stranger = signIn("stranger");
        String snapId = record(owner, "owned", "food", 100);
        UUID missing = UUID.fromString("00000000-0000-4000-8000-000000000099");

        String foreign = mockMvc.perform(get("/api/v1/snaps/" + snapId)
                        .header("Authorization", "Bearer " + stranger))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_ACCESSIBLE"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String unknown = mockMvc.perform(get("/api/v1/snaps/" + missing)
                        .header("Authorization", "Bearer " + stranger))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_ACCESSIBLE"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        assertThat(JsonPath.read(foreign, "$.code").toString())
                .isEqualTo(JsonPath.read(unknown, "$.code").toString());

        mockMvc.perform(patch("/api/v1/snaps/" + snapId)
                        .header("Authorization", "Bearer " + stranger)
                        .contentType("application/json")
                        .content(revise("x", 1, "cafe", 200)))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_ACCESSIBLE"));
        mockMvc.perform(delete("/api/v1/snaps/" + missing)
                        .header("Authorization", "Bearer " + owner)
                        .header("X-Client-Mutation-Id", "missing-delete"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_ACCESSIBLE"));
    }

    @Test
    void rejectsStaleVersionAndUnknownReviseProperties() throws Exception {
        String accessToken = signIn("version-owner");
        String snapId = record(accessToken, "v1", "food", 100);

        mockMvc.perform(patch("/api/v1/snaps/" + snapId)
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content(revise("ok", 1, "cafe", 200)))
                .andExpect(status().isOk());
        mockMvc.perform(patch("/api/v1/snaps/" + snapId)
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content(revise("stale", 1, "living", 300)))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("SNAP_VERSION_CONFLICT"));
        mockMvc.perform(patch("/api/v1/snaps/" + snapId)
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content(revise("ok", 1, "food", 100).replace("}", ",\"localDay\":\"2026-08-13\"}")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
        assertThat(jdbc.sql("SELECT category FROM snaps").query(String.class).single()).isEqualTo("cafe");
    }

    @Test
    void deleteMutationConflictAndMissingBearerStayCanonical() throws Exception {
        String accessToken = signIn("delete-owner");
        String first = record(accessToken, "one", "food", 100);
        String second = record(accessToken, "two", "cafe", 200);

        mockMvc.perform(delete("/api/v1/snaps/" + first)
                        .header("Authorization", "Bearer " + accessToken)
                        .header("X-Client-Mutation-Id", "shared-delete"))
                .andExpect(status().isNoContent());
        mockMvc.perform(delete("/api/v1/snaps/" + second)
                        .header("Authorization", "Bearer " + accessToken)
                        .header("X-Client-Mutation-Id", "shared-delete"))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("MUTATION_CONFLICT"));
        mockMvc.perform(get("/api/v1/snaps/" + first))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("SESSION_REJECTED"));
    }

    private String signIn(String subject) throws Exception {
        String accessToken = "access-" + subject;
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();
        jdbc.sql("INSERT INTO users (id, created_at) VALUES (:id, :now)")
                .param("id", userId).param("now", Timestamp.from(NOW)).update();
        jdbc.sql("INSERT INTO apple_identities (user_id, apple_subject, created_at, updated_at) "
                        + "VALUES (:userId, :subject, :now, :now)")
                .param("userId", userId).param("subject", subject)
                .param("now", Timestamp.from(NOW)).update();
        jdbc.sql("""
                INSERT INTO identity_sessions (
                    id, user_id, access_token_hash, access_expires_at,
                    refresh_expires_at, created_at, last_used_at
                ) VALUES (:id, :userId, :hash, :accessExpiresAt, :refreshExpiresAt, :now, :now)
                """)
                .param("id", sessionId).param("userId", userId).param("hash", sha256(accessToken))
                .param("accessExpiresAt", Timestamp.from(NOW.plusSeconds(30 * 86_400)))
                .param("refreshExpiresAt", Timestamp.from(NOW.plusSeconds(86_400)))
                .param("now", Timestamp.from(NOW)).update();
        return accessToken;
    }

    private static String sha256(String value) throws Exception {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                .digest(value.getBytes(StandardCharsets.UTF_8)));
    }

    private String record(String accessToken, String mutationId, String category, long amountWon) throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/snaps")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"%s","localDay":"2026-08-14","timeZone":"Asia/Seoul",\
                                "category":"%s","amountWon":%d}
                                """.formatted(mutationId, category, amountWon)))
                .andExpect(status().isCreated())
                .andReturn();
        return JsonPath.read(result.getResponse().getContentAsString(), "$.id");
    }

    private org.springframework.test.web.servlet.ResultActions today(String accessToken) throws Exception {
        return mockMvc.perform(get("/api/v1/snaps/today")
                .header("Authorization", "Bearer " + accessToken)
                .queryParam("timeZone", "Asia/Seoul"));
    }

    private static String revise(String mutationId, int version, String category, long amountWon) {
        return """
                {"clientMutationId":"%s","expectedVersion":%d,"category":"%s","amountWon":%d}
                """.formatted(mutationId, version, category, amountWon);
    }
}
