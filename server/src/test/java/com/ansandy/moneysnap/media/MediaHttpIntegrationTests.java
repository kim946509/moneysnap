package com.ansandy.moneysnap.media;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.util.HexFormat;
import java.util.UUID;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.put;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@Testcontainers
@AutoConfigureMockMvc
@SpringBootTest
class MediaHttpIntegrationTests {

    private static final Instant NOW = Instant.parse("2026-08-13T15:30:00Z");

    @Container
    private static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(
            DockerImageName.parse("postgres:18-alpine"));

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcClient jdbc;

    @Autowired
    private MediaCleanup cleanup;

    @Autowired
    private MediaVault vault;

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
        jdbc.sql("TRUNCATE TABLE media_cleanup_tombstones, snap_share_mutations, snap_shares, media_objects, group_join_mutations, "
                + "group_invites, group_delete_mutations, group_create_mutations, group_memberships, "
                + "spend_groups, snap_delete_mutations, snap_revise_mutations, snap_record_mutations, snaps, "
                + "identity_refresh_tokens, identity_sessions, apple_identities, users CASCADE").update();
    }

    @Test
    void uploadsABoundedJpegAndAttachesItToAPersonalSnap() throws Exception {
        String accessToken = signIn("media-owner");
        byte[] jpeg = jpegFixture(128);
        String checksum = sha256(jpeg);
        String intent = mockMvc.perform(post("/api/v1/media/intents")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content("""
                                {"byteSize":%d,"contentType":"image/jpeg","checksumSha256":"%s"}
                                """.formatted(jpeg.length, checksum)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.mode").value("bounded-stream"))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String imageRef = JsonPath.read(intent, "$.imageRef");
        mockMvc.perform(put("/api/v1/media/" + imageRef + "/upload")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("image/jpeg")
                        .content(jpeg))
                .andExpect(status().isNoContent());
        mockMvc.perform(post("/api/v1/media/" + imageRef + "/complete")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.imageRef").value(imageRef));
        String recordBody = mockMvc.perform(post("/api/v1/snaps")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"with-photo","localDay":"2026-08-14","timeZone":"Asia/Seoul",\
                                "category":"food","amountWon":100,"imageRef":"%s"}
                                """.formatted(imageRef)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.imageRef").value(imageRef))
                .andReturn()
                .getResponse()
                .getContentAsString();
        String snapId = JsonPath.read(recordBody, "$.id");
        mockMvc.perform(get("/api/v1/media/" + imageRef)
                        .header("Authorization", "Bearer " + accessToken)
                        .accept(MediaType.IMAGE_JPEG))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.IMAGE_JPEG))
                .andExpect(content().bytes(jpeg));
        mockMvc.perform(get("/api/v1/snaps/today")
                        .header("Authorization", "Bearer " + accessToken)
                        .queryParam("timeZone", "Asia/Seoul"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.snaps[0].id").value(snapId))
                .andExpect(jsonPath("$.snaps[0].imageRef").value(imageRef));
        mockMvc.perform(get("/api/v1/snaps/" + snapId)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.imageRef").value(imageRef));
        mockMvc.perform(get("/api/v1/snaps/archive")
                        .header("Authorization", "Bearer " + accessToken)
                        .queryParam("fromLocalDay", "2026-08-14")
                        .queryParam("toLocalDay", "2026-08-14"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.snaps[0].imageRef").value(imageRef));
    }

    @Test
    void groupMemberCanReadASharedLinkedJpegAndAStrangerCannot() throws Exception {
        String owner = signIn("media-share-owner");
        String member = signIn("media-share-member");
        String stranger = signIn("media-share-stranger");
        byte[] jpeg = jpegFixture(96);
        String checksum = sha256(jpeg);
        String intent = mockMvc.perform(post("/api/v1/media/intents")
                        .header("Authorization", "Bearer " + owner)
                        .contentType("application/json")
                        .content("""
                                {"byteSize":%d,"contentType":"image/jpeg","checksumSha256":"%s"}
                                """.formatted(jpeg.length, checksum)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String imageRef = JsonPath.read(intent, "$.imageRef");
        mockMvc.perform(put("/api/v1/media/" + imageRef + "/upload")
                        .header("Authorization", "Bearer " + owner)
                        .contentType("image/jpeg")
                        .content(jpeg))
                .andExpect(status().isNoContent());
        mockMvc.perform(post("/api/v1/media/" + imageRef + "/complete")
                        .header("Authorization", "Bearer " + owner))
                .andExpect(status().isOk());
        String snapId = JsonPath.read(mockMvc.perform(post("/api/v1/snaps")
                        .header("Authorization", "Bearer " + owner)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"shared-photo","localDay":"2026-08-14","timeZone":"Asia/Seoul",\
                                "category":"food","amountWon":100,"imageRef":"%s"}
                                """.formatted(imageRef)))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString(), "$.id");
        String groupId = JsonPath.read(mockMvc.perform(post("/api/v1/groups")
                        .header("Authorization", "Bearer " + owner)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"photo-group","name":"사진","amountVisible":false}
                                """))
                .andExpect(status().isCreated())
                .andReturn()
                .getResponse()
                .getContentAsString(), "$.id");
        String code = JsonPath.read(mockMvc.perform(post("/api/v1/groups/" + groupId + "/invites")
                        .header("Authorization", "Bearer " + owner))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString(), "$.code");
        mockMvc.perform(post("/api/v1/invites/join")
                        .header("Authorization", "Bearer " + member)
                        .contentType("application/json")
                        .content("{\"code\":\"" + code + "\",\"clientMutationId\":\"join-photo\"}"))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/shares")
                        .header("Authorization", "Bearer " + owner)
                        .contentType("application/json")
                        .content("""
                                {"clientMutationId":"share-photo","snapId":"%s","groupId":"%s"}
                                """.formatted(snapId, groupId)))
                .andExpect(status().isCreated());
        String today = mockMvc.perform(get("/api/v1/groups/" + groupId + "/today")
                        .header("Authorization", "Bearer " + member)
                        .queryParam("timeZone", "Asia/Seoul"))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        assertThat(today).contains("\"imageRef\":\"" + imageRef + "\"");
        assertThat(today).doesNotContain("amountWon", "totalAmountWon");
        mockMvc.perform(get("/api/v1/media/" + imageRef)
                        .header("Authorization", "Bearer " + member)
                        .accept(MediaType.IMAGE_JPEG))
                .andExpect(status().isOk())
                .andExpect(content().contentType(MediaType.IMAGE_JPEG))
                .andExpect(content().bytes(jpeg));
        mockMvc.perform(get("/api/v1/media/" + imageRef)
                        .header("Authorization", "Bearer " + stranger))
                .andExpect(status().isNotFound());
    }

    @Test
    void expiredPendingAndAbortedMediaAreRemovedByCleanup() throws Exception {
        String accessToken = signIn("cleanup-owner");
        byte[] jpeg = jpegFixture(64);
        String checksum = sha256(jpeg);
        String intent = mockMvc.perform(post("/api/v1/media/intents")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("application/json")
                        .content("""
                                {"byteSize":%d,"contentType":"image/jpeg","checksumSha256":"%s"}
                                """.formatted(jpeg.length, checksum)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();
        String imageRef = JsonPath.read(intent, "$.imageRef");
        mockMvc.perform(put("/api/v1/media/" + imageRef + "/upload")
                        .header("Authorization", "Bearer " + accessToken)
                        .contentType("image/jpeg")
                        .content(jpeg))
                .andExpect(status().isNoContent());
        mockMvc.perform(post("/api/v1/media/" + imageRef + "/complete")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isOk());
        mockMvc.perform(post("/api/v1/media/" + imageRef + "/abort")
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNoContent());
        assertThat(cleanup.sweep()).isGreaterThanOrEqualTo(1);
        mockMvc.perform(get("/api/v1/media/" + imageRef)
                        .header("Authorization", "Bearer " + accessToken))
                .andExpect(status().isNotFound());
    }

    @Test
    void accountDeletionCopiesMediaKeysToTombstonesThenRemovesUserRows() throws Exception {
        signIn("tombstone-owner");
        UUID userId = jdbc.sql("SELECT id FROM users").query(UUID.class).single();
        String key = "users/" + userId + "/orphan.jpg";
        jdbc.sql("""
                INSERT INTO media_objects (
                    id, owner_id, object_key, content_type, declared_bytes, checksum_sha256,
                    status, created_at
                ) VALUES (
                    :id, :ownerId, :key, 'image/jpeg', 32, :checksum, 'ACTIVE_UNLINKED', :now
                )
                """)
                .param("id", UUID.randomUUID())
                .param("ownerId", userId)
                .param("key", key)
                .param("checksum", "a".repeat(64))
                .param("now", Timestamp.from(NOW))
                .update();
        vault.transferToTombstones(userId);
        assertThat(jdbc.sql("SELECT count(*) FROM media_cleanup_tombstones").query(Integer.class).single()).isOne();
        jdbc.sql("DELETE FROM users WHERE id = :id").param("id", userId).update();
        assertThat(jdbc.sql("SELECT count(*) FROM media_objects").query(Integer.class).single()).isZero();
        assertThat(jdbc.sql("SELECT count(*) FROM media_cleanup_tombstones").query(Integer.class).single()).isOne();
        cleanup.sweep();
        assertThat(jdbc.sql("SELECT status FROM media_cleanup_tombstones").query(String.class).single())
                .isEqualTo("DONE");
    }

    private static byte[] jpegFixture(int size) {
        byte[] bytes = new byte[size];
        bytes[0] = (byte) 0xFF;
        bytes[1] = (byte) 0xD8;
        bytes[2] = (byte) 0xFF;
        return bytes;
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
        return sha256(value.getBytes(StandardCharsets.UTF_8));
    }

    private static String sha256(byte[] value) throws Exception {
        return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value));
    }
}
