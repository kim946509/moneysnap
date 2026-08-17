package com.ansandy.moneysnap.identity;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Timestamp;
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
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@Testcontainers
@AutoConfigureMockMvc
@SpringBootTest
class AccountSummaryHttpIntegrationTests {

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
        jdbc.sql("TRUNCATE TABLE snap_share_mutations, snap_shares, group_invites, group_delete_mutations, "
                + "group_create_mutations, group_memberships, spend_groups, snap_delete_mutations, "
                + "snap_revise_mutations, snap_record_mutations, snaps, identity_refresh_tokens, "
                + "identity_sessions, apple_identities, users CASCADE").update();
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
}
