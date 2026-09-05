package com.ansandy.moneysnap.group;

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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@AutoConfigureMockMvc
@SpringBootTest
class GroupHttpIntegrationTests {

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
    void ownerCreatesListsAndDeletesAGroupWithoutTouchingPersonalSnaps() throws Exception {
        String accessToken = signIn("owner");
        mockMvc.perform(post("/api/v1/snaps")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"snap-1","localDay":"2026-08-14","timeZone":"Asia/Seoul",\
                                "category":"food","amountWon":100}
                                """))
                .andExpect(status().isCreated());

        MvcResult created = mockMvc.perform(post("/api/v1/groups")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"group-1","name":" 주말 모임 ","amountVisible":true}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.name").value("주말 모임"))
                .andExpect(jsonPath("$.amountVisible").value(true))
                .andExpect(jsonPath("$.role").value("owner"))
                .andReturn();
        Map<String, Object> body = JsonPath.parse(created.getResponse().getContentAsString()).read("$");
        assertThat(body.keySet()).isEqualTo(Set.of("id", "name", "amountVisible", "role", "createdAt"));
        String groupId = body.get("id").toString();

        mockMvc.perform(post("/api/v1/groups")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"group-1","name":" 주말 모임 ","amountVisible":true}
                                """))
                .andExpect(status().isCreated())
                .andExpect(result -> assertThat(result.getResponse().getContentAsString())
                        .isEqualTo(created.getResponse().getContentAsString()));

        mockMvc.perform(get("/api/v1/groups")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.groups.length()").value(1))
                .andExpect(jsonPath("$.groups[0].id").value(groupId));

        mockMvc.perform(delete("/api/v1/groups/" + groupId)
                        .header("Authorization", "Bearer " + accessToken)
                        .header("X-Client-Mutation-Id", "delete-group"))
                .andExpect(status().isNoContent());
        mockMvc.perform(get("/api/v1/groups/" + groupId)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_ACCESSIBLE"));
        assertThat(jdbc.sql("SELECT count(*) FROM snaps").query(Integer.class).single()).isOne();

        MvcResult createdAgain = mockMvc.perform(post("/api/v1/groups")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"group-2","name":"다시","amountVisible":false}
                                """))
                .andExpect(status().isCreated())
                .andReturn();
        String newGroupId = JsonPath.read(createdAgain.getResponse().getContentAsString(), "$.id");
        String snapId = jdbc.sql("SELECT id FROM snaps").query(SqliteColumns::firstUuid).single().toString();
        mockMvc.perform(post("/api/v1/shares")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"share-1","snapId":"%s","groupId":"%s"}
                                """.formatted(snapId, newGroupId)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.snapId").value(snapId))
                .andExpect(jsonPath("$.groupId").value(newGroupId));
    }

    @Test
    void rejectsBlankNamesUnknownPropertiesAndForeignGroupAccess() throws Exception {
        String owner = signIn("owner");
        String stranger = signIn("stranger");
        mockMvc.perform(post("/api/v1/groups")
                        .header("Authorization", "Bearer " + owner)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"bad","name":"   ","amountVisible":false}
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
        MvcResult created = mockMvc.perform(post("/api/v1/groups")
                        .header("Authorization", "Bearer " + owner)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"ok","name":"친구","amountVisible":false}
                                """))
                .andExpect(status().isCreated())
                .andReturn();
        String groupId = JsonPath.read(created.getResponse().getContentAsString(), "$.id");
        mockMvc.perform(get("/api/v1/groups/" + groupId)
                        .header("Authorization", "Bearer " + stranger))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_ACCESSIBLE"));
        mockMvc.perform(get("/api/v1/groups")
                        .header("Authorization", "Bearer " + stranger))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.groups.length()").value(0));
    }

    @Test
    void ownerInviteLetsAnotherUserJoinAndSeeHiddenTodayWithoutAmounts() throws Exception {
        String owner = signIn("invite-owner");
        String member = signIn("invite-member");
        MvcResult created = mockMvc.perform(post("/api/v1/groups")
                        .header("Authorization", "Bearer " + owner)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"hidden-group","name":"비공개","amountVisible":false}
                                """))
                .andExpect(status().isCreated())
                .andReturn();
        String groupId = JsonPath.read(created.getResponse().getContentAsString(), "$.id");
        MvcResult issued = mockMvc.perform(post("/api/v1/groups/" + groupId + "/invites")
                        .header("Authorization", "Bearer " + owner))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.code").isNotEmpty())
                .andExpect(jsonPath("$.expiresAt").value("2026-08-20T15:30:00Z"))
                .andReturn();
        String code = JsonPath.read(issued.getResponse().getContentAsString(), "$.code");
        assertThat(jdbc.sql("SELECT token_hash FROM group_invites").query(String.class).single())
                .isNotEqualTo(code);

        mockMvc.perform(post("/api/v1/invites/preview")
                        .header("Authorization", "Bearer " + member)
                        .contentType("application/json")
                        .content("{\"code\":\"" + code + "\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.name").value("비공개"))
                .andExpect(jsonPath("$.amountVisible").value(false));

        mockMvc.perform(post("/api/v1/invites/join")
                        .header("Authorization", "Bearer " + member)
                        .contentType("application/json")
                        .content("{\"code\":\"" + code + "\",\"clientMutationId\":\"join-1\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.role").value("member"));
        mockMvc.perform(post("/api/v1/invites/join")
                        .header("Authorization", "Bearer " + member)
                        .contentType("application/json")
                        .content("{\"code\":\"" + code + "\",\"clientMutationId\":\"join-1\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.role").value("member"));

        String snapId = JsonPath.read(mockMvc.perform(post("/api/v1/snaps")
                        .header("Authorization", "Bearer " + member)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"shared-snap","localDay":"2026-08-14","timeZone":"Asia/Seoul",\
                                "category":"food","amountWon":18900}
                                """))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString(), "$.id");
        mockMvc.perform(post("/api/v1/shares")
                        .header("Authorization", "Bearer " + member)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"share-hidden","snapId":"%s","groupId":"%s"}
                                """.formatted(snapId, groupId)))
                .andExpect(status().isCreated());

        MvcResult today = mockMvc.perform(get("/api/v1/groups/" + groupId + "/today")
                        .header("Authorization", "Bearer " + owner)
                        .queryParam("timeZone", "Asia/Seoul"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.members.length()").value(2))
                .andReturn();
        String body = today.getResponse().getContentAsString();
        assertThat(body).doesNotContain("amountWon", "totalAmountWon", "amount", "total");
        assertThat(body).contains("\"category\":\"food\"");

        mockMvc.perform(delete("/api/v1/groups/" + groupId + "/members/me")
                        .header("Authorization", "Bearer " + member))
                .andExpect(status().isNoContent());
        mockMvc.perform(get("/api/v1/groups/" + groupId + "/today")
                        .header("Authorization", "Bearer " + member)
                        .queryParam("timeZone", "Asia/Seoul"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_ACCESSIBLE"));
        assertThat(jdbc.sql("SELECT count(*) FROM snaps").query(Integer.class).single()).isOne();
    }

    @Test
    void visibleGroupTodayIncludesAmountsAndRejectsUnknownInviteCodes() throws Exception {
        String owner = signIn("visible-owner");
        MvcResult created = mockMvc.perform(post("/api/v1/groups")
                        .header("Authorization", "Bearer " + owner)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"visible-group","name":"공개","amountVisible":true}
                                """))
                .andExpect(status().isCreated())
                .andReturn();
        String groupId = JsonPath.read(created.getResponse().getContentAsString(), "$.id");
        String snapId = JsonPath.read(mockMvc.perform(post("/api/v1/snaps")
                        .header("Authorization", "Bearer " + owner)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"owner-snap","localDay":"2026-08-14","timeZone":"Asia/Seoul",\
                                "category":"cafe","amountWon":5200}
                                """))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString(), "$.id");
        mockMvc.perform(post("/api/v1/shares")
                        .header("Authorization", "Bearer " + owner)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"share-visible","snapId":"%s","groupId":"%s"}
                                """.formatted(snapId, groupId)))
                .andExpect(status().isCreated());
        mockMvc.perform(get("/api/v1/groups/" + groupId + "/today")
                        .header("Authorization", "Bearer " + owner)
                        .queryParam("timeZone", "Asia/Seoul"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.members[0].totalAmountWon").value(5200))
                .andExpect(jsonPath("$.members[0].representative.amountWon").value(5200))
                .andExpect(jsonPath("$.members[0].representative.imageRef").doesNotExist());
        mockMvc.perform(post("/api/v1/invites/preview")
                        .header("Authorization", "Bearer " + owner)
                        .contentType("application/json")
                        .content("{\"code\":\"deadbeefdeadbeefdeadbeefdeadbeef\"}"))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NOT_ACCESSIBLE"));
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
