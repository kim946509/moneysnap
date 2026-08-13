package com.ansandy.moneysnap.snap;

import java.time.Clock;
import java.time.Instant;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import javax.sql.DataSource;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.context.bean.override.mockito.MockitoSpyBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.postgresql.PostgreSQLContainer;
import org.testcontainers.utility.DockerImageName;

import com.ansandy.moneysnap.shared.AuthenticatedUser;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.reset;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.authentication;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@Testcontainers
@AutoConfigureMockMvc
@SpringBootTest
class SnapRecordHttpIntegrationTests {

    private static final Instant NOW = Instant.parse("2026-08-13T15:30:00Z");
    private static final long MUTATION_CONTENTION_LOCK = 72_021L;

    @Container
    private static final PostgreSQLContainer POSTGRES = new PostgreSQLContainer(
            DockerImageName.parse("postgres:18-alpine"));

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private JdbcClient jdbc;

    @MockitoSpyBean
    private DataSource dataSource;

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
        jdbc.sql("TRUNCATE TABLE snap_record_mutations, snaps, identity_refresh_tokens, "
                + "identity_sessions, apple_identities, users CASCADE").update();
    }

    @Test
    void recordsAPrivateSnapAndReturnsItsExactRepresentation() throws Exception {
        String accessToken = signIn("snap-owner");

        MvcResult result = record(accessToken, validRequest("record-1", "food", 18_900))
                .andExpect(status().isCreated())
                .andExpect(header().string("Location", org.hamcrest.Matchers.matchesPattern(
                        "/api/v1/snaps/[0-9a-f-]{36}")))
                .andExpect(jsonPath("$.id").isNotEmpty())
                .andExpect(jsonPath("$.category").value("food"))
                .andExpect(jsonPath("$.amountWon").value(18_900))
                .andExpect(jsonPath("$.localDay").value("2026-08-14"))
                .andExpect(jsonPath("$.createdAt").value("2026-08-13T15:30:00Z"))
                .andReturn();

        Map<String, Object> body = JsonPath.parse(result.getResponse().getContentAsString()).read("$");
        assertThat(body.keySet()).isEqualTo(Set.of("id", "category", "amountWon", "localDay", "createdAt"));
        assertThat(result.getResponse().getHeader("Location")).isEqualTo("/api/v1/snaps/" + body.get("id"));
    }

    @Test
    void replaysTheFirstResultBeforeDynamicDateValidation() throws Exception {
        String accessToken = signIn("replay-owner");
        String request = validRequest("replay-key", "food", 18_900);
        MvcResult first = record(accessToken, request).andExpect(status().isCreated()).andReturn();

        given(clock.instant()).willReturn(NOW.plusSeconds(2 * 86_400));
        MvcResult replay = record(accessToken, request).andExpect(status().isCreated()).andReturn();

        assertThat(JsonPath.read(replay.getResponse().getContentAsString(), "$.id").toString())
                .isEqualTo(JsonPath.read(first.getResponse().getContentAsString(), "$.id").toString());
        assertThat(rowCount("snaps")).isOne();
    }

    @Test
    void returnsTheSameDatabaseCanonicalReceiptForFirstRecordAndReplay() throws Exception {
        Instant nanosecondNow = Instant.parse("2026-08-13T15:30:00.123456789Z");
        given(clock.instant()).willReturn(nanosecondNow);
        String accessToken = signIn("canonical-receipt-owner");
        String request = validRequest("canonical-receipt", "food", 18_900);

        MvcResult first = record(accessToken, request).andExpect(status().isCreated()).andReturn();
        MvcResult replay = record(accessToken, request).andExpect(status().isCreated()).andReturn();

        assertThat(replay.getResponse().getContentAsString())
                .isEqualTo(first.getResponse().getContentAsString());
        assertThat(JsonPath.read(first.getResponse().getContentAsString(), "$.createdAt").toString())
                .isNotEqualTo(nanosecondNow.toString());
    }

    @Test
    void replaysTheOriginalRecordReceiptAfterTheSnapIsHardDeleted() throws Exception {
        String accessToken = signIn("deleted-record-owner");
        String request = validRequest("deleted-record-key", "food", 18_900);
        MvcResult first = record(accessToken, request).andExpect(status().isCreated()).andReturn();
        UUID snapId = UUID.fromString(responseId(first));

        jdbc.sql("DELETE FROM snaps WHERE id = :id").param("id", snapId).update();

        MvcResult replay = record(accessToken, request).andExpect(status().isCreated()).andReturn();
        assertThat(replay.getResponse().getContentAsString())
                .isEqualTo(first.getResponse().getContentAsString());
        record(accessToken, validRequest("deleted-record-key", "cafe", 18_900))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("MUTATION_CONFLICT"));
        assertThat(rowCount("snaps")).isZero();
        assertThat(rowCount("snap_record_mutations")).isOne();
    }

    @Test
    void rejectsMutationReuseWithADifferentPayloadAndPreservesTheFirstSnap() throws Exception {
        String accessToken = signIn("conflict-owner");
        MvcResult first = record(accessToken, validRequest("conflict-key", "food", 18_900))
                .andExpect(status().isCreated()).andReturn();

        record(accessToken, validRequest("conflict-key", "cafe", 18_900))
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("MUTATION_CONFLICT"))
                .andExpect(jsonPath("$.correlationId").isNotEmpty());

        assertThat(rowCount("snaps")).isOne();
        assertThat(jdbc.sql("SELECT category FROM snaps").query(String.class).single()).isEqualTo("food");
        assertThat(JsonPath.read(first.getResponse().getContentAsString(), "$.category").toString())
                .isEqualTo("food");
    }

    @Test
    void scopesMutationKeysToTheAuthenticatedOwner() throws Exception {
        String firstOwner = signIn("first-owner");
        String secondOwner = signIn("second-owner");

        String firstId = responseId(record(firstOwner, validRequest("shared-key", "food", 100))
                .andExpect(status().isCreated()).andReturn());
        String secondId = responseId(record(secondOwner, validRequest("shared-key", "cafe", 200))
                .andExpect(status().isCreated()).andReturn());

        assertThat(firstId).isNotEqualTo(secondId);
        assertThat(rowCount("snaps")).isEqualTo(2);
    }

    @Test
    void rejectsMissingBearerWithTheCanonicalSessionError() throws Exception {
        mockMvc.perform(post("/api/v1/snaps")
                        .contentType("application/json")
                        .content(validRequest("no-bearer", "food", 100)))
                .andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("SESSION_REJECTED"))
                .andExpect(jsonPath("$.correlationId").isNotEmpty());
    }

    @Test
    void strictlyRejectsUnknownAndOwnershipPropertiesWithoutSaving() throws Exception {
        String accessToken = signIn("strict-owner");
        for (String property : Set.of("futureField", "ownerId", "groupId", "visibility", "imageId")) {
            String request = validRequest("strict-" + property, "food", 100)
                    .replace("}", ",\"" + property + "\":\"forbidden\"}");
            record(accessToken, request)
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("INVALID_REQUEST"))
                    .andExpect(jsonPath("$.correlationId").isNotEmpty());
        }
        assertThat(rowCount("snaps")).isZero();
    }

    @Test
    void rejectsInvalidMoneyCategoryTimezoneDayAndMalformedBodyWithoutSaving() throws Exception {
        String accessToken = signIn("validation-owner");
        String base = validRequest("invalid-key", "food", 100);
        for (String request : Set.of(
                base.replace("100", "0"),
                base.replace("100", "1000000000"),
                base.replace("food", "FOOD"),
                base.replace("Asia/Seoul", "+09:00"),
                base.replace("Asia/Seoul", "GMT"),
                base.replace("2026-08-14", "2026-08-15"),
                base.replace("2026-08-14", "2026-08-12"),
                "{bad-json")) {
            record(accessToken, request)
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("INVALID_REQUEST"));
        }
        assertThat(rowCount("snaps")).isZero();
        assertThat(rowCount("snap_record_mutations")).isZero();
    }

    @Test
    void rejectsCoercedJsonTokenTypesWithoutSaving() throws Exception {
        String accessToken = signIn("token-type-owner");
        String base = validRequest("token-type-key", "food", 100);
        for (String request : List.of(
                base.replace("\"amountWon\":100", "\"amountWon\":1.5"),
                base.replace("\"amountWon\":100", "\"amountWon\":\"100\""),
                base.replace("\"clientMutationId\":\"token-type-key\"", "\"clientMutationId\":123"),
                base.replace("\"localDay\":\"2026-08-14\"", "\"localDay\":20260814"),
                base.replace("\"timeZone\":\"Asia/Seoul\"", "\"timeZone\":9"),
                base.replace("\"category\":\"food\"", "\"category\":1"))) {
            record(accessToken, request)
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("INVALID_REQUEST"))
                    .andExpect(jsonPath("$.correlationId").isNotEmpty());
        }
        assertThat(rowCount("snaps")).isZero();
        assertThat(rowCount("snap_record_mutations")).isZero();
    }

    @Test
    void measuresMutationKeyLengthInUnicodeCodePoints() throws Exception {
        String accessToken = signIn("unicode-key-owner");
        String astralCharacter = "\uD83D\uDE80";

        record(accessToken, validRequest(astralCharacter.repeat(128), "food", 100))
                .andExpect(status().isCreated());
        record(accessToken, validRequest(astralCharacter.repeat(129), "cafe", 200))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("INVALID_REQUEST"))
                .andExpect(jsonPath("$.correlationId").isNotEmpty());

        assertThat(rowCount("snaps")).isOne();
        assertThat(rowCount("snap_record_mutations")).isOne();
    }

    @Test
    void rollsBackAReservationWhenDynamicDateValidationFails() throws Exception {
        String accessToken = signIn("date-rollback-owner");
        record(accessToken, validRequest("rollback-key", "food", 100)
                        .replace("2026-08-14", "2026-08-15"))
                .andExpect(status().isBadRequest());

        record(accessToken, validRequest("rollback-key", "food", 100))
                .andExpect(status().isCreated());
        assertThat(rowCount("snaps")).isOne();
        assertThat(rowCount("snap_record_mutations")).isOne();
    }

    @Test
    void returnsASafeInternalErrorAndRollsBackWhenTheSnapInsertFails() throws Exception {
        String accessToken = signIn("trigger-owner");
        jdbc.sql("""
                CREATE FUNCTION reject_snap_insert() RETURNS trigger LANGUAGE plpgsql AS $$
                BEGIN RAISE EXCEPTION 'sensitive database failure'; END $$
                """).update();
        jdbc.sql("CREATE TRIGGER reject_snap BEFORE INSERT ON snaps "
                + "FOR EACH ROW EXECUTE FUNCTION reject_snap_insert()").update();
        try {
            MvcResult failed = record(accessToken, validRequest("trigger-key", "food", 100))
                    .andExpect(status().isInternalServerError())
                    .andExpect(jsonPath("$.code").value("INTERNAL_ERROR"))
                    .andExpect(jsonPath("$.correlationId").isNotEmpty())
                    .andReturn();
            Map<String, Object> body = JsonPath.parse(failed.getResponse().getContentAsString()).read("$");
            assertThat(body.keySet()).containsExactlyInAnyOrder("code", "correlationId");
            assertThat(failed.getResponse().getContentAsString())
                    .doesNotContain("sensitive", "INSERT", "snap_record_mutations");
            assertThat(rowCount("snaps")).isZero();
            assertThat(rowCount("snap_record_mutations")).isZero();
        }
        finally {
            jdbc.sql("DROP TRIGGER IF EXISTS reject_snap ON snaps").update();
            jdbc.sql("DROP FUNCTION IF EXISTS reject_snap_insert()").update();
        }

        record(accessToken, validRequest("trigger-key", "food", 100))
                .andExpect(status().isCreated());
    }

    @Test
    void returnsASafeInternalErrorAndRollsBackWhenTransactionCommitFails() throws Exception {
        String accessToken = signIn("commit-trigger-owner");
        jdbc.sql("""
                CREATE FUNCTION reject_snap_commit() RETURNS trigger LANGUAGE plpgsql AS $$
                BEGIN RAISE EXCEPTION 'sensitive deferred commit failure'; END $$
                """).update();
        jdbc.sql("""
                CREATE CONSTRAINT TRIGGER reject_snap_commit
                AFTER INSERT ON snaps DEFERRABLE INITIALLY DEFERRED
                FOR EACH ROW EXECUTE FUNCTION reject_snap_commit()
                """).update();
        try {
            MvcResult failed = record(accessToken, validRequest("commit-trigger-key", "food", 100))
                    .andExpect(status().isInternalServerError())
                    .andExpect(jsonPath("$.code").value("INTERNAL_ERROR"))
                    .andExpect(jsonPath("$.correlationId").isNotEmpty())
                    .andReturn();
            Map<String, Object> body = JsonPath.parse(failed.getResponse().getContentAsString()).read("$");
            assertThat(body.keySet()).containsExactlyInAnyOrder("code", "correlationId");
            assertThat(failed.getResponse().getContentAsString())
                    .doesNotContain("sensitive", "commit", "snap_record_mutations");
            assertThat(rowCount("snaps")).isZero();
            assertThat(rowCount("snap_record_mutations")).isZero();
        }
        finally {
            jdbc.sql("DROP TRIGGER IF EXISTS reject_snap_commit ON snaps").update();
            jdbc.sql("DROP FUNCTION IF EXISTS reject_snap_commit()").update();
        }
    }

    @Test
    void returnsASafeInternalErrorWhenTransactionCannotBegin() throws Exception {
        var authenticatedUser = UsernamePasswordAuthenticationToken.authenticated(
                new AuthenticatedUser(UUID.randomUUID()), "", List.of());
        doThrow(new SQLException("sensitive connection failure"))
                .when(dataSource).getConnection();
        MvcResult failed;
        try {
            failed = mockMvc.perform(post("/api/v1/snaps")
                            .with(authentication(authenticatedUser))
                            .contentType("application/json")
                            .content(validRequest("begin-failure-key", "food", 100)))
                    .andExpect(status().isInternalServerError())
                    .andExpect(jsonPath("$.code").value("INTERNAL_ERROR"))
                    .andExpect(jsonPath("$.correlationId").isNotEmpty())
                    .andReturn();
        }
        finally {
            reset(dataSource);
        }

        Map<String, Object> body = JsonPath.parse(failed.getResponse().getContentAsString()).read("$");
        assertThat(body.keySet()).containsExactlyInAnyOrder("code", "correlationId");
        assertThat(failed.getResponse().getContentAsString())
                .doesNotContain("sensitive", "connection", "transaction");
        assertThat(rowCount("snaps")).isZero();
        assertThat(rowCount("snap_record_mutations")).isZero();
    }

    @Test
    void serializesConcurrentIdenticalRequestsToOneSnap() throws Exception {
        String accessToken = signIn("same-concurrent-owner");
        String request = validRequest("same-concurrent", "food", 100);
        ConcurrentResult result = concurrently(
                () -> record(accessToken, request).andReturn(),
                () -> record(accessToken, request).andReturn());

        assertThat(List.of(result.first().getResponse().getStatus(), result.second().getResponse().getStatus()))
                .containsOnly(201);
        assertThat(responseId(result.first())).isEqualTo(responseId(result.second()));
        assertThat(rowCount("snaps")).isOne();
    }

    @Test
    void serializesConcurrentDifferentPayloadsToCreatedAndConflict() throws Exception {
        String accessToken = signIn("different-concurrent-owner");
        ConcurrentResult result = concurrently(
                () -> record(accessToken, validRequest("different-concurrent", "food", 100)).andReturn(),
                () -> record(accessToken, validRequest("different-concurrent", "cafe", 200)).andReturn());

        assertThat(Set.of(result.first().getResponse().getStatus(), result.second().getResponse().getStatus()))
                .containsExactlyInAnyOrder(201, 409);
        assertThat(rowCount("snaps")).isOne();
    }

    @Test
    void cascadesTheOwnersSnapsAndMutationLedgerWhenTheAccountIsDeleted() throws Exception {
        String accessToken = signIn("cascade-owner");
        record(accessToken, validRequest("cascade-key", "food", 100)).andExpect(status().isCreated());
        UUID ownerId = jdbc.sql("SELECT id FROM users").query(UUID.class).single();

        jdbc.sql("DELETE FROM users WHERE id = :id").param("id", ownerId).update();

        assertThat(rowCount("snaps")).isZero();
        assertThat(rowCount("snap_record_mutations")).isZero();
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

    private int rowCount(String table) {
        return jdbc.sql("SELECT count(*) FROM " + table).query(Integer.class).single();
    }

    private static String responseId(MvcResult result) throws Exception {
        return JsonPath.read(result.getResponse().getContentAsString(), "$.id");
    }

    private ConcurrentResult concurrently(ThrowingRequest first, ThrowingRequest second) throws Exception {
        CountDownLatch ready = new CountDownLatch(2);
        CountDownLatch start = new CountDownLatch(1);
        ExecutorService executor = Executors.newFixedThreadPool(2);
        Future<MvcResult> firstResult = null;
        Future<MvcResult> secondResult = null;
        Connection lockConnection = null;
        boolean advisoryLockHeld = false;
        installMutationContentionTrigger();
        try {
            lockConnection = DriverManager.getConnection(
                    POSTGRES.getJdbcUrl(), POSTGRES.getUsername(), POSTGRES.getPassword());
            executeAdvisoryLock(lockConnection, "pg_advisory_lock");
            advisoryLockHeld = true;
            firstResult = executor.submit(() -> {
                ready.countDown();
                if (!start.await(5, TimeUnit.SECONDS)) {
                    throw new IllegalStateException("Concurrent request start timed out");
                }
                return first.perform();
            });
            secondResult = executor.submit(() -> {
                ready.countDown();
                if (!start.await(5, TimeUnit.SECONDS)) {
                    throw new IllegalStateException("Concurrent request start timed out");
                }
                return second.perform();
            });
            if (!ready.await(5, TimeUnit.SECONDS)) {
                throw new IllegalStateException("Concurrent requests did not become ready");
            }
            start.countDown();
            awaitMutationContention(2, 5, TimeUnit.SECONDS);
            executeAdvisoryLock(lockConnection, "pg_advisory_unlock");
            advisoryLockHeld = false;
            return new ConcurrentResult(
                    firstResult.get(10, TimeUnit.SECONDS),
                    secondResult.get(10, TimeUnit.SECONDS));
        }
        finally {
            start.countDown();
            if (lockConnection != null) {
                try {
                    if (advisoryLockHeld) {
                        executeAdvisoryLock(lockConnection, "pg_advisory_unlock");
                    }
                }
                finally {
                    lockConnection.close();
                }
            }
            if (firstResult != null) {
                firstResult.cancel(true);
            }
            if (secondResult != null) {
                secondResult.cancel(true);
            }
            executor.shutdownNow();
            boolean terminated = executor.awaitTermination(5, TimeUnit.SECONDS);
            try {
                removeMutationContentionTrigger();
            }
            finally {
                if (!terminated) {
                    throw new IllegalStateException("Concurrent request executor did not terminate");
                }
            }
        }
    }

    private static void executeAdvisoryLock(Connection connection, String operation) throws SQLException {
        try (var statement = connection.createStatement()) {
            statement.setQueryTimeout(5);
            statement.execute("SELECT " + operation + "(" + MUTATION_CONTENTION_LOCK + ")");
        }
    }

    private void installMutationContentionTrigger() {
        removeMutationContentionTrigger();
        jdbc.sql("""
                CREATE FUNCTION block_snap_record_mutation() RETURNS trigger LANGUAGE plpgsql AS $$
                BEGIN
                    PERFORM pg_advisory_xact_lock(72021);
                    RETURN NEW;
                END $$
                """).update();
        jdbc.sql("""
                CREATE TRIGGER block_snap_record_mutation
                AFTER INSERT ON snap_record_mutations
                FOR EACH ROW EXECUTE FUNCTION block_snap_record_mutation()
                """).update();
    }

    private void removeMutationContentionTrigger() {
        jdbc.sql("DROP TRIGGER IF EXISTS block_snap_record_mutation ON snap_record_mutations").update();
        jdbc.sql("DROP FUNCTION IF EXISTS block_snap_record_mutation()").update();
    }

    private void awaitMutationContention(int expectedWaiters, long timeout, TimeUnit unit)
            throws InterruptedException {
        long deadline = System.nanoTime() + unit.toNanos(timeout);
        while (System.nanoTime() < deadline) {
            int waiters = jdbc.sql("""
                    SELECT count(*)
                    FROM pg_stat_activity
                    WHERE datname = current_database()
                      AND wait_event_type = 'Lock'
                      AND query ILIKE '%INSERT INTO snap_record_mutations%'
                    """).query(Integer.class).single();
            if (waiters >= expectedWaiters) {
                return;
            }
            Thread.sleep(10);
        }
        throw new IllegalStateException("Concurrent requests did not overlap at the mutation ledger");
    }

    @FunctionalInterface
    private interface ThrowingRequest {
        MvcResult perform() throws Exception;
    }

    private record ConcurrentResult(MvcResult first, MvcResult second) {
    }

    private org.springframework.test.web.servlet.ResultActions record(String accessToken, String body)
            throws Exception {
        return mockMvc.perform(post("/api/v1/snaps")
                .header("Authorization", "Bearer " + accessToken)
                .contentType("application/json")
                .content(body));
    }

    private static String validRequest(String mutationId, String category, long amountWon) {
        return """
                {"clientMutationId":"%s","localDay":"2026-08-14","timeZone":"Asia/Seoul",\
                "category":"%s","amountWon":%d}
                """.formatted(mutationId, category, amountWon);
    }
}
