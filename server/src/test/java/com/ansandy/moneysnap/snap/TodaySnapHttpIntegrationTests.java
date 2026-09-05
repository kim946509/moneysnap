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
import com.ansandy.moneysnap.shared.SqliteColumns;

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
import com.ansandy.moneysnap.SqliteTestDatabase;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@SpringBootTest
class TodaySnapHttpIntegrationTests {

    private static final Instant NOW = Instant.parse("2026-08-13T15:30:00Z");


    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcClient jdbc;

    @MockitoBean(name = "identityClock")
    private Clock clock;

    @DynamicPropertySource
    static void databaseProperties(DynamicPropertyRegistry registry) {
        SqliteTestDatabase.register(registry);
    }

    @BeforeEach
    void resetDatabase() {
        given(clock.instant()).willReturn(NOW);
        SqliteTestDatabase.clear(jdbc);
    }

    @Test
    void returnsOwnerTodaySnapsInStableOrderWithOverflowSafeTotal() throws Exception {
        String accessToken = signIn("today-owner");
        String firstId = record(accessToken, "first", "food", 18_900, "2026-08-14");
        given(clock.instant()).willReturn(NOW.plusSeconds(1));
        String secondId = record(accessToken, "second", "cafe", 5_200, "2026-08-14");
        given(clock.instant()).willReturn(NOW);
        record(accessToken, "yesterday", "living", 16_300, "2026-08-13");
        signIn("other-owner");
        String otherToken = signIn("foreign-owner");
        record(otherToken, "foreign", "food", 999_999_999, "2026-08-14");

        MvcResult result = today(accessToken, "Asia/Seoul")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.localDay").value("2026-08-14"))
                .andExpect(jsonPath("$.totalAmountWon").value(24_100))
                .andExpect(jsonPath("$.snaps.length()").value(2))
                .andExpect(jsonPath("$.snaps[0].id").value(secondId))
                .andExpect(jsonPath("$.snaps[0].category").value("cafe"))
                .andExpect(jsonPath("$.snaps[0].amountWon").value(5_200))
                .andExpect(jsonPath("$.snaps[0].localDay").value("2026-08-14"))
                .andExpect(jsonPath("$.snaps[1].id").value(firstId))
                .andReturn();

        Map<String, Object> body = JsonPath.parse(result.getResponse().getContentAsString()).read("$");
        assertThat(body.keySet()).isEqualTo(Set.of("localDay", "totalAmountWon", "snaps"));
        Map<String, Object> firstSnap = JsonPath.parse(result.getResponse().getContentAsString())
                .read("$.snaps[0]");
        assertThat(firstSnap.keySet())
                .isEqualTo(Set.of("id", "category", "amountWon", "localDay", "createdAt"));
        assertThat(result.getResponse().getContentAsString())
                .doesNotContain("ownerId", "sessionId", "groupId", "visibility");
    }

    @Test
    void returnsTheSameSchemaWithZeroTotalWhenTheOwnerHasNoTodaySnaps() throws Exception {
        String accessToken = signIn("empty-owner");

        MvcResult result = today(accessToken, "Asia/Seoul")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.localDay").value("2026-08-14"))
                .andExpect(jsonPath("$.totalAmountWon").value(0))
                .andExpect(jsonPath("$.snaps.length()").value(0))
                .andReturn();

        Map<String, Object> body = JsonPath.parse(result.getResponse().getContentAsString()).read("$");
        assertThat(body.keySet()).isEqualTo(Set.of("localDay", "totalAmountWon", "snaps"));
    }

    @Test
    void usesTheSubmittedZoneToChooseTodayWithoutRelabelingStoredDays() throws Exception {
        String accessToken = signIn("utc-owner");
        record(accessToken, "utc-today", "food", 100, "2026-08-13");
        record(accessToken, "seoul-today", "cafe", 200, "2026-08-14");

        today(accessToken, "UTC")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.localDay").value("2026-08-13"))
                .andExpect(jsonPath("$.totalAmountWon").value(100))
                .andExpect(jsonPath("$.snaps.length()").value(1))
                .andExpect(jsonPath("$.snaps[0].localDay").value("2026-08-13"));
    }

    @Test
    void rejectsMissingNumericOffsetAndUnknownTimeZonesWithoutReadingSnaps() throws Exception {
        String accessToken = signIn("zone-owner");
        record(accessToken, "kept", "food", 100, "2026-08-14");

        mockMvc.perform(get("/api/v1/snaps/today")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
        today(accessToken, "+09:00").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
        today(accessToken, "GMT").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
        today(accessToken, "Mars/Olympus").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
    }

    @Test
    void rejectsMissingBearerWithTheCanonicalSessionError() throws Exception {
        mockMvc.perform(get("/api/v1/snaps/today").queryParam("timeZone", "Asia/Seoul"))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("SESSION_REJECTED"))
                .andExpect(jsonPath("$.correlationId").isNotEmpty());
    }

    @Test
    void tiesEqualCreatedAtByDescendingSnapId() throws Exception {
        String accessToken = signIn("tie-owner");
        UUID ownerId = jdbc.sql("SELECT id FROM users").query(SqliteColumns::firstUuid).single();
        UUID smaller = UUID.fromString("00000000-0000-4000-8000-000000000001");
        UUID larger = UUID.fromString("ffffffff-ffff-4fff-8fff-ffffffffffff");
        insertSnap(smaller, ownerId, "food", 100);
        insertSnap(larger, ownerId, "cafe", 200);

        today(accessToken, "Asia/Seoul")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.snaps[0].id").value(larger.toString()))
                .andExpect(jsonPath("$.snaps[1].id").value(smaller.toString()))
                .andExpect(jsonPath("$.totalAmountWon").value(300));
    }

    private void insertSnap(UUID id, UUID ownerId, String category, long amountWon) {
        jdbc.sql("""
                INSERT INTO snaps (id, owner_id, category, amount_won, local_day, created_at, updated_at, version)
                VALUES (:id, :ownerId, :category, :amountWon, '2026-08-14', :createdAt, :createdAt, 1)
                """)
                .param("id", id)
                .param("ownerId", ownerId)
                .param("category", category)
                .param("amountWon", amountWon)
                .param("createdAt", SqliteColumns.instant(NOW))
                .update();
    }

    private String signIn(String subject) throws Exception {
        String accessToken = "access-" + subject;
        UUID userId = UUID.randomUUID();
        UUID sessionId = UUID.randomUUID();
        jdbc.sql("INSERT INTO users (id, created_at) VALUES (:id, :now)")
                .param("id", userId).param("now", SqliteColumns.instant(NOW)).update();
        jdbc.sql("INSERT INTO apple_identities (user_id, apple_subject, created_at, updated_at) "
                        + "VALUES (:userId, :subject, :now, :now)")
                .param("userId", userId).param("subject", subject)
                .param("now", SqliteColumns.instant(NOW)).update();
        jdbc.sql("""
                INSERT INTO identity_sessions (
                    id, user_id, access_token_hash, access_expires_at,
                    refresh_expires_at, created_at, last_used_at
                ) VALUES (:id, :userId, :hash, :accessExpiresAt, :refreshExpiresAt, :now, :now)
                """)
                .param("id", sessionId).param("userId", userId).param("hash", sha256(accessToken))
                .param("accessExpiresAt", SqliteColumns.instant(NOW.plusSeconds(30 * 86_400)))
                .param("refreshExpiresAt", SqliteColumns.instant(NOW.plusSeconds(86_400)))
                .param("now", SqliteColumns.instant(NOW)).update();
        return accessToken;
    }

    private static String sha256(String value) throws Exception {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                .digest(value.getBytes(StandardCharsets.UTF_8)));
    }

    private String record(String accessToken, String mutationId, String category, long amountWon, String localDay)
            throws Exception {
        MvcResult result = mockMvc.perform(post("/api/v1/snaps")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"%s","localDay":"%s","timeZone":"Asia/Seoul",\
                                "category":"%s","amountWon":%d}
                                """.formatted(mutationId, localDay, category, amountWon)))
                .andExpect(status().isCreated())
                .andReturn();
        return JsonPath.read(result.getResponse().getContentAsString(), "$.id");
    }

    private org.springframework.test.web.servlet.ResultActions today(String accessToken, String timeZone)
            throws Exception {
        return mockMvc.perform(get("/api/v1/snaps/today")
                .header("Authorization", "Bearer " + accessToken)
                .queryParam("timeZone", timeZone));
    }
}
