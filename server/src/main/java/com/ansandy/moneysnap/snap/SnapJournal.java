package com.ansandy.moneysnap.snap;

import java.sql.Date;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

import com.fasterxml.jackson.annotation.JsonInclude;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.support.TransactionTemplate;

final class SnapJournal {

    private final JdbcClient jdbc;
    private final TransactionTemplate transactions;
    private final Clock clock;

    SnapJournal(JdbcClient jdbc, TransactionTemplate transactions, Clock clock) {
        this.jdbc = Objects.requireNonNull(jdbc);
        this.transactions = Objects.requireNonNull(transactions);
        this.clock = Objects.requireNonNull(clock);
    }

    SnapRecordReceipt record(UUID ownerId, SnapRecordCommand command) {
        Objects.requireNonNull(ownerId, "ownerId");
        Objects.requireNonNull(command, "command");
        return transactions.execute(status -> recordInTransaction(ownerId, command));
    }

    TodaySnapshot today(UUID ownerId, String timeZone) {
        Objects.requireNonNull(ownerId, "ownerId");
        ZoneId zone = SnapTimeZones.requireRegionOrUtc(timeZone);
        LocalDate localDay = LocalDate.ofInstant(clock.instant(), zone);
        List<SnapRecordReceipt> snaps = jdbc.sql("""
                SELECT id, category, amount_won, local_day, created_at, image_id
                FROM snaps
                WHERE owner_id = :ownerId AND local_day = :localDay
                ORDER BY created_at DESC, id DESC
                """)
                .param("ownerId", ownerId)
                .param("localDay", Date.valueOf(localDay))
                .query(this::mapReceipt)
                .list();
        return TodaySnapshot.of(localDay, snaps);
    }

    SnapDetail get(UUID ownerId, UUID snapId) {
        Objects.requireNonNull(ownerId, "ownerId");
        Objects.requireNonNull(snapId, "snapId");
        return findOwnedDetail(ownerId, snapId).orElseThrow(SnapNotAccessibleException::new);
    }

    SnapDetail revise(UUID ownerId, UUID snapId, SnapReviseCommand command) {
        Objects.requireNonNull(ownerId, "ownerId");
        Objects.requireNonNull(snapId, "snapId");
        Objects.requireNonNull(command, "command");
        return transactions.execute(status -> reviseInTransaction(ownerId, snapId, command));
    }

    ArchivePage archive(UUID ownerId, LocalDate from, LocalDate to, int limit, String cursor) {
        Objects.requireNonNull(ownerId, "ownerId");
        Objects.requireNonNull(from, "from");
        Objects.requireNonNull(to, "to");
        if (from.isAfter(to) || java.time.temporal.ChronoUnit.DAYS.between(from, to) > 41) {
            throw new IllegalArgumentException("Archive range must be at most 42 inclusive days");
        }
        if (limit < 1 || limit > 50) {
            throw new IllegalArgumentException("Archive limit must be 1 to 50");
        }
        ArchiveCursor decoded = cursor == null || cursor.isBlank() ? null : ArchiveCursor.decode(cursor, from, to, limit);
        String sql = """
                SELECT id, category, amount_won, local_day, created_at, image_id
                FROM snaps
                WHERE owner_id = :ownerId
                  AND local_day BETWEEN :fromDay AND :toDay
                """;
        if (decoded != null) {
            sql += """
                   AND (local_day, created_at, id) < (:cursorDay, :cursorCreatedAt, :cursorId)
                   """;
        }
        sql += " ORDER BY local_day DESC, created_at DESC, id DESC LIMIT :limit";
        var query = jdbc.sql(sql)
                .param("ownerId", ownerId)
                .param("fromDay", Date.valueOf(from))
                .param("toDay", Date.valueOf(to))
                .param("limit", limit + 1);
        if (decoded != null) {
            query = query.param("cursorDay", Date.valueOf(decoded.localDay()))
                    .param("cursorCreatedAt", Timestamp.from(decoded.createdAt()))
                    .param("cursorId", decoded.id());
        }
        List<SnapRecordReceipt> rows = query.query(this::mapReceipt).list();
        boolean hasMore = rows.size() > limit;
        if (hasMore) {
            rows = rows.subList(0, limit);
        }
        String next = null;
        if (hasMore && !rows.isEmpty()) {
            SnapRecordReceipt last = rows.get(rows.size() - 1);
            next = new ArchiveCursor(from, to, limit, last.localDay(), last.createdAt(), last.id()).encode();
        }
        List<LocalDate> occupied = List.of();
        if (decoded == null) {
            occupied = jdbc.sql("""
                    SELECT DISTINCT local_day
                    FROM snaps
                    WHERE owner_id = :ownerId AND local_day BETWEEN :fromDay AND :toDay
                    ORDER BY local_day DESC
                    """)
                    .param("ownerId", ownerId)
                    .param("fromDay", Date.valueOf(from))
                    .param("toDay", Date.valueOf(to))
                    .query((row, rowNumber) -> row.getObject("local_day", LocalDate.class))
                    .list();
        }
        return new ArchivePage(rows, next, occupied);
    }

    void delete(UUID ownerId, UUID snapId, String clientMutationId) {
        Objects.requireNonNull(ownerId, "ownerId");
        Objects.requireNonNull(snapId, "snapId");
        SnapDeleteCommand command = new SnapDeleteCommand(clientMutationId, snapId);
        transactions.executeWithoutResult(status -> deleteInTransaction(ownerId, command));
    }

    private SnapRecordReceipt recordInTransaction(UUID ownerId, SnapRecordCommand command) {
        String fingerprint = command.fingerprint();
        Instant now = clock.instant();
        int claimed = jdbc.sql("""
                INSERT INTO snap_record_mutations (
                    owner_id, client_mutation_id, request_fingerprint, created_at
                ) VALUES (:ownerId, :mutationId, :fingerprint, :createdAt)
                ON CONFLICT (owner_id, client_mutation_id) DO NOTHING
                """)
                .param("ownerId", ownerId)
                .param("mutationId", command.clientMutationId())
                .param("fingerprint", fingerprint)
                .param("createdAt", Timestamp.from(now))
                .update();

        if (claimed == 0) {
            MutationRecord existing = findMutation(ownerId, command.clientMutationId()).orElseThrow();
            if (!existing.fingerprint().equals(fingerprint)) {
                throw new SnapMutationConflictException();
            }
            return new SnapRecordReceipt(
                    existing.snapId(),
                    command.category().code(),
                    command.amount().value(),
                    command.localDay(),
                    existing.createdAt(),
                    command.imageRef());
        }

        command.validateLocalDay(clock);
        UUID snapId = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO snaps (
                    id, owner_id, category, amount_won, local_day, created_at, updated_at, version
                ) VALUES (
                    :id, :ownerId, :category, :amountWon, :localDay, :createdAt, :createdAt, 1
                )
                """)
                .param("id", snapId)
                .param("ownerId", ownerId)
                .param("category", command.category().code())
                .param("amountWon", command.amount().value())
                .param("localDay", Date.valueOf(command.localDay()))
                .param("createdAt", Timestamp.from(now))
                .update();
        if (command.imageRef() != null) {
            int linked = jdbc.sql("""
                    UPDATE media_objects
                    SET status = 'LINKED'
                    WHERE id = :mediaId AND owner_id = :ownerId AND status = 'ACTIVE_UNLINKED'
                      AND (orphan_expires_at IS NULL OR orphan_expires_at > :now)
                    """)
                    .param("mediaId", command.imageRef())
                    .param("ownerId", ownerId)
                    .param("now", Timestamp.from(now))
                    .update();
            if (linked != 1) {
                throw new SnapNotAccessibleException();
            }
            jdbc.sql("UPDATE snaps SET image_id = :mediaId WHERE id = :id")
                    .param("mediaId", command.imageRef())
                    .param("id", snapId)
                    .update();
        }
        jdbc.sql("""
                UPDATE snap_record_mutations SET snap_id = :snapId
                WHERE owner_id = :ownerId AND client_mutation_id = :mutationId
                """)
                .param("snapId", snapId)
                .param("ownerId", ownerId)
                .param("mutationId", command.clientMutationId())
                .update();
        return findSnap(snapId).orElseThrow();
    }

    private Optional<MutationRecord> findMutation(UUID ownerId, String mutationId) {
        return jdbc.sql("""
                SELECT request_fingerprint, snap_id, created_at
                FROM snap_record_mutations
                WHERE owner_id = :ownerId AND client_mutation_id = :mutationId
                FOR UPDATE
                """)
                .param("ownerId", ownerId)
                .param("mutationId", mutationId)
                .query((row, rowNumber) -> new MutationRecord(
                        row.getString("request_fingerprint"),
                        row.getObject("snap_id", UUID.class),
                        row.getTimestamp("created_at").toInstant()))
                .optional();
    }

    private SnapDetail reviseInTransaction(UUID ownerId, UUID snapId, SnapReviseCommand command) {
        String fingerprint = command.fingerprint(snapId);
        Instant now = clock.instant();
        int claimed = jdbc.sql("""
                INSERT INTO snap_revise_mutations (
                    owner_id, client_mutation_id, request_fingerprint, snap_id,
                    category, amount_won, local_day, snap_created_at, updated_at, version, created_at
                ) VALUES (
                    :ownerId, :mutationId, :fingerprint, :snapId,
                    :category, :amountWon, DATE '1970-01-01', :now, :now, 0, :now
                )
                ON CONFLICT (owner_id, client_mutation_id) DO NOTHING
                """)
                .param("ownerId", ownerId)
                .param("mutationId", command.clientMutationId())
                .param("fingerprint", fingerprint)
                .param("snapId", snapId)
                .param("category", command.category().code())
                .param("amountWon", command.amount().value())
                .param("now", Timestamp.from(now))
                .update();

        if (claimed == 0) {
            SnapDetail existing = findReviseMutation(ownerId, command.clientMutationId()).orElseThrow();
            if (!existingFingerprint(ownerId, command.clientMutationId()).equals(fingerprint)) {
                throw new SnapMutationConflictException();
            }
            return existing;
        }

        SnapDetail current = findOwnedDetailForUpdate(ownerId, snapId)
                .orElseThrow(SnapNotAccessibleException::new);
        if (current.version() != command.expectedVersion()) {
            throw new SnapVersionConflictException();
        }
        int updated = jdbc.sql("""
                UPDATE snaps
                SET category = :category, amount_won = :amountWon, updated_at = :updatedAt, version = :version
                WHERE id = :id AND owner_id = :ownerId AND version = :expectedVersion
                """)
                .param("category", command.category().code())
                .param("amountWon", command.amount().value())
                .param("updatedAt", Timestamp.from(now))
                .param("version", command.expectedVersion() + 1)
                .param("id", snapId)
                .param("ownerId", ownerId)
                .param("expectedVersion", command.expectedVersion())
                .update();
        if (updated != 1) {
            throw new SnapVersionConflictException();
        }
        SnapDetail revised = findOwnedDetail(ownerId, snapId).orElseThrow();
        jdbc.sql("""
                UPDATE snap_revise_mutations
                SET category = :category, amount_won = :amountWon, local_day = :localDay,
                    snap_created_at = :snapCreatedAt, updated_at = :updatedAt, version = :version
                WHERE owner_id = :ownerId AND client_mutation_id = :mutationId
                """)
                .param("category", revised.category())
                .param("amountWon", revised.amountWon())
                .param("localDay", Date.valueOf(revised.localDay()))
                .param("snapCreatedAt", Timestamp.from(revised.createdAt()))
                .param("updatedAt", Timestamp.from(revised.updatedAt()))
                .param("version", revised.version())
                .param("ownerId", ownerId)
                .param("mutationId", command.clientMutationId())
                .update();
        return revised;
    }

    private void deleteInTransaction(UUID ownerId, SnapDeleteCommand command) {
        String fingerprint = command.fingerprint();
        Instant now = clock.instant();
        int claimed = jdbc.sql("""
                INSERT INTO snap_delete_mutations (
                    owner_id, client_mutation_id, request_fingerprint, snap_id, created_at
                ) VALUES (:ownerId, :mutationId, :fingerprint, :snapId, :createdAt)
                ON CONFLICT (owner_id, client_mutation_id) DO NOTHING
                """)
                .param("ownerId", ownerId)
                .param("mutationId", command.clientMutationId())
                .param("fingerprint", fingerprint)
                .param("snapId", command.snapId())
                .param("createdAt", Timestamp.from(now))
                .update();

        if (claimed == 0) {
            DeleteMutation existing = findDeleteMutation(ownerId, command.clientMutationId()).orElseThrow();
            if (!existing.fingerprint().equals(fingerprint)) {
                throw new SnapMutationConflictException();
            }
            return;
        }

        UUID imageId = jdbc.sql("SELECT image_id FROM snaps WHERE id = :id AND owner_id = :ownerId")
                .param("id", command.snapId())
                .param("ownerId", ownerId)
                .query(UUID.class)
                .optional()
                .orElse(null);
        int deleted = jdbc.sql("""
                DELETE FROM snaps WHERE id = :id AND owner_id = :ownerId
                """)
                .param("id", command.snapId())
                .param("ownerId", ownerId)
                .update();
        if (deleted != 1) {
            throw new SnapNotAccessibleException();
        }
        if (imageId != null) {
            jdbc.sql("""
                    UPDATE media_objects
                    SET status = 'CLEANUP_CLAIMED', attempt_count = attempt_count + 1
                    WHERE id = :id AND owner_id = :ownerId AND status = 'LINKED'
                    """)
                    .param("id", imageId)
                    .param("ownerId", ownerId)
                    .update();
        }
    }

    private Optional<SnapRecordReceipt> findSnap(UUID snapId) {
        return jdbc.sql("""
                SELECT id, category, amount_won, local_day, created_at, image_id
                FROM snaps WHERE id = :snapId
                """)
                .param("snapId", snapId)
                .query(this::mapReceipt)
                .optional();
    }

    private Optional<SnapDetail> findOwnedDetail(UUID ownerId, UUID snapId) {
        return jdbc.sql("""
                SELECT id, category, amount_won, local_day, created_at, updated_at, version, image_id
                FROM snaps
                WHERE id = :id AND owner_id = :ownerId
                """)
                .param("id", snapId)
                .param("ownerId", ownerId)
                .query(this::mapDetail)
                .optional();
    }

    private Optional<SnapDetail> findOwnedDetailForUpdate(UUID ownerId, UUID snapId) {
        return jdbc.sql("""
                SELECT id, category, amount_won, local_day, created_at, updated_at, version, image_id
                FROM snaps
                WHERE id = :id AND owner_id = :ownerId
                FOR UPDATE
                """)
                .param("id", snapId)
                .param("ownerId", ownerId)
                .query(this::mapDetail)
                .optional();
    }

    private Optional<SnapDetail> findReviseMutation(UUID ownerId, String mutationId) {
        return jdbc.sql("""
                SELECT snap_id, category, amount_won, local_day, snap_created_at, updated_at, version
                FROM snap_revise_mutations
                WHERE owner_id = :ownerId AND client_mutation_id = :mutationId
                FOR UPDATE
                """)
                .param("ownerId", ownerId)
                .param("mutationId", mutationId)
                .query((row, rowNumber) -> new SnapDetail(
                        row.getObject("snap_id", UUID.class),
                        row.getString("category"),
                        row.getLong("amount_won"),
                        row.getObject("local_day", LocalDate.class),
                        row.getTimestamp("snap_created_at").toInstant(),
                        row.getTimestamp("updated_at").toInstant(),
                        row.getInt("version"),
                        null))
                .optional();
    }

    private String existingFingerprint(UUID ownerId, String mutationId) {
        return jdbc.sql("""
                SELECT request_fingerprint
                FROM snap_revise_mutations
                WHERE owner_id = :ownerId AND client_mutation_id = :mutationId
                """)
                .param("ownerId", ownerId)
                .param("mutationId", mutationId)
                .query(String.class)
                .single();
    }

    private Optional<DeleteMutation> findDeleteMutation(UUID ownerId, String mutationId) {
        return jdbc.sql("""
                SELECT request_fingerprint, snap_id
                FROM snap_delete_mutations
                WHERE owner_id = :ownerId AND client_mutation_id = :mutationId
                FOR UPDATE
                """)
                .param("ownerId", ownerId)
                .param("mutationId", mutationId)
                .query((row, rowNumber) -> new DeleteMutation(
                        row.getString("request_fingerprint"),
                        row.getObject("snap_id", UUID.class)))
                .optional();
    }

    private SnapRecordReceipt mapReceipt(java.sql.ResultSet row, int rowNumber) throws java.sql.SQLException {
        return new SnapRecordReceipt(
                row.getObject("id", UUID.class),
                row.getString("category"),
                row.getLong("amount_won"),
                row.getObject("local_day", LocalDate.class),
                row.getTimestamp("created_at").toInstant(),
                row.getObject("image_id", UUID.class));
    }

    private SnapDetail mapDetail(java.sql.ResultSet row, int rowNumber) throws java.sql.SQLException {
        return new SnapDetail(
                row.getObject("id", UUID.class),
                row.getString("category"),
                row.getLong("amount_won"),
                row.getObject("local_day", LocalDate.class),
                row.getTimestamp("created_at").toInstant(),
                row.getTimestamp("updated_at").toInstant(),
                row.getInt("version"),
                row.getObject("image_id", UUID.class));
    }

    private record MutationRecord(String fingerprint, UUID snapId, Instant createdAt) {
    }

    private record DeleteMutation(String fingerprint, UUID snapId) {
    }
}

@JsonInclude(JsonInclude.Include.NON_NULL)
record SnapRecordReceipt(
        UUID id,
        String category,
        long amountWon,
        LocalDate localDay,
        Instant createdAt,
        UUID imageRef) {
}

record TodaySnapshot(LocalDate localDay, long totalAmountWon, List<SnapRecordReceipt> snaps) {

    static TodaySnapshot of(LocalDate localDay, List<SnapRecordReceipt> snaps) {
        Objects.requireNonNull(localDay, "localDay");
        List<SnapRecordReceipt> copy = List.copyOf(snaps);
        if (copy.stream().anyMatch(snap -> !snap.localDay().equals(localDay))) {
            throw new IllegalArgumentException("Every Today Snap must belong to the requested local day");
        }
        long total = copy.stream()
                .mapToLong(SnapRecordReceipt::amountWon)
                .reduce(0L, Math::addExact);
        return new TodaySnapshot(localDay, total, copy);
    }
}

@JsonInclude(JsonInclude.Include.NON_NULL)
record SnapDetail(
        UUID id,
        String category,
        long amountWon,
        LocalDate localDay,
        Instant createdAt,
        Instant updatedAt,
        int version,
        UUID imageRef) {
}

@JsonInclude(JsonInclude.Include.NON_EMPTY)
record ArchivePage(List<SnapRecordReceipt> snaps, String nextCursor, List<LocalDate> occupiedLocalDays) {
}

record ArchiveCursor(
        LocalDate from,
        LocalDate to,
        int limit,
        LocalDate localDay,
        Instant createdAt,
        UUID id) {

    String encode() {
        return java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(
                (from + "|" + to + "|" + limit + "|" + localDay + "|" + createdAt + "|" + id)
                        .getBytes(java.nio.charset.StandardCharsets.UTF_8));
    }

    static ArchiveCursor decode(String cursor, LocalDate from, LocalDate to, int limit) {
        try {
            String raw = new String(java.util.Base64.getUrlDecoder().decode(cursor),
                    java.nio.charset.StandardCharsets.UTF_8);
            String[] parts = raw.split("\\|");
            if (parts.length != 6) {
                throw new InvalidCursorException();
            }
            ArchiveCursor decoded = new ArchiveCursor(
                    LocalDate.parse(parts[0]),
                    LocalDate.parse(parts[1]),
                    Integer.parseInt(parts[2]),
                    LocalDate.parse(parts[3]),
                    Instant.parse(parts[4]),
                    UUID.fromString(parts[5]));
            if (!decoded.from().equals(from) || !decoded.to().equals(to) || decoded.limit() != limit) {
                throw new InvalidCursorException();
            }
            return decoded;
        }
        catch (RuntimeException exception) {
            throw new InvalidCursorException();
        }
    }
}

final class InvalidCursorException extends RuntimeException {
}

final class SnapMutationConflictException extends RuntimeException {
}

final class SnapVersionConflictException extends RuntimeException {
}

final class SnapNotAccessibleException extends RuntimeException {
}
