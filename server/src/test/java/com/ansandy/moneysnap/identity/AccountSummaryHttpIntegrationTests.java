package com.ansandy.moneysnap.identity;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Timestamp;
import com.ansandy.moneysnap.shared.SqliteColumns;
import java.time.Clock;
import java.time.Instant;
import java.util.HexFormat;
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
import com.ansandy.moneysnap.SqliteTestDatabase;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@SpringBootTest
class AccountSummaryHttpIntegrationTests {

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
    void returnsExactSummaryFieldsForTheAuthenticatedOwner() throws Exception {
        String accessToken = signIn("summary-owner");
        mockMvc.perform(post("/api/v1/snaps")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"s1","localDay":"2026-08-14","timeZone":"Asia/Seoul",\
                                "category":"food","amountWon":100}
                                """))
                .andExpect(status().isCreated());
        mockMvc.perform(post("/api/v1/groups")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"g1","name":"모임","amountVisible":true}
                                """))
                .andExpect(status().isCreated());

        MvcResult result = mockMvc.perform(get("/api/v1/account/summary")
                        .header("Authorization", "Bearer " + accessToken)
                        .queryParam("timeZone", "Asia/Seoul"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.displayName").value("MoneySnap 사용자"))
                .andExpect(jsonPath("$.todaySnapCount").value(1))
                .andExpect(jsonPath("$.monthSnapCount").value(1))
                .andExpect(jsonPath("$.groupCount").value(1))
                .andReturn();
        assertThat(JsonPath.parse(result.getResponse().getContentAsString()).<java.util.Map<String, Object>>read("$")
                .keySet())
                .isEqualTo(Set.of("displayName", "todaySnapCount", "monthSnapCount", "groupCount"));
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
}
