package com.ansandy.moneysnap.snap;

import java.sql.Date;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

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
                    existing.createdAt());
        }

        command.validateLocalDay(clock);
        UUID snapId = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO snaps (id, owner_id, category, amount_won, local_day, created_at)
                VALUES (:id, :ownerId, :category, :amountWon, :localDay, :createdAt)
                """)
                .param("id", snapId)
                .param("ownerId", ownerId)
                .param("category", command.category().code())
                .param("amountWon", command.amount().value())
                .param("localDay", Date.valueOf(command.localDay()))
                .param("createdAt", Timestamp.from(now))
                .update();
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

    private Optional<SnapRecordReceipt> findSnap(UUID snapId) {
        return jdbc.sql("""
                SELECT id, category, amount_won, local_day, created_at
                FROM snaps WHERE id = :snapId
                """)
                .param("snapId", snapId)
                .query((row, rowNumber) -> new SnapRecordReceipt(
                        row.getObject("id", UUID.class),
                        row.getString("category"),
                        row.getLong("amount_won"),
                        row.getObject("local_day", LocalDate.class),
                        row.getTimestamp("created_at").toInstant()))
                .optional();
    }

    private record MutationRecord(String fingerprint, UUID snapId, Instant createdAt) {
    }
}

record SnapRecordReceipt(
        UUID id,
        String category,
        long amountWon,
        LocalDate localDay,
        Instant createdAt) {
}

final class SnapMutationConflictException extends RuntimeException {
}
