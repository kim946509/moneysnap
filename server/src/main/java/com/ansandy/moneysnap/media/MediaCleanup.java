package com.ansandy.moneysnap.media;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

import com.ansandy.moneysnap.shared.SqliteColumns;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.scheduling.annotation.Scheduled;

final class MediaCleanup {

    static final int MAX_ATTEMPTS = 5;

    private final JdbcClient jdbc;
    private final Clock clock;
    private final ObjectStore objects;

    MediaCleanup(JdbcClient jdbc, Clock clock, ObjectStore objects) {
        this.jdbc = Objects.requireNonNull(jdbc);
        this.clock = Objects.requireNonNull(clock);
        this.objects = Objects.requireNonNull(objects);
    }

    @Scheduled(fixedDelay = 60_000)
    void scheduledSweep() {
        sweep();
    }

    int sweep() {
        Instant now = clock.instant();
        claimEligibleMedia(now);
        return cleanClaimedMedia(now) + cleanTombstones(now);
    }

    private void claimEligibleMedia(Instant now) {
        List<UUID> eligible = jdbc.sql("""
                SELECT id FROM media_objects
                WHERE (
                    (status = 'PENDING' AND expires_at <= :now)
                    OR status = 'FAILED'
                    OR (status = 'ACTIVE_UNLINKED' AND orphan_expires_at IS NOT NULL AND orphan_expires_at <= :now)
                )
                AND (next_attempt_at IS NULL OR next_attempt_at <= :now)
                """)
                .param("now", SqliteColumns.instant(now))
                .query(SqliteColumns::firstUuid)
                .list();
        for (UUID id : eligible) {
            jdbc.sql("""
                    UPDATE media_objects
                    SET status = 'CLEANUP_CLAIMED', attempt_count = attempt_count + 1, next_attempt_at = :next
                    WHERE id = :id
                      AND status IN ('PENDING', 'FAILED', 'ACTIVE_UNLINKED')
                    """)
                    .param("next", SqliteColumns.instant(now.plus(Duration.ofMinutes(1))))
                    .param("id", id)
                    .update();
        }
    }

    private int cleanClaimedMedia(Instant now) {
        List<CleanupTarget> claimed = jdbc.sql("""
                SELECT id, object_key, attempt_count
                FROM media_objects
                WHERE status = 'CLEANUP_CLAIMED'
                """)
                .query((row, rowNumber) -> new CleanupTarget(
                        SqliteColumns.uuid(row, "id"),
                        row.getString("object_key"),
                        row.getInt("attempt_count"),
                        false))
                .list();
        int cleaned = 0;
        for (CleanupTarget target : claimed) {
            if (deleteObject(target)) {
                jdbc.sql("DELETE FROM media_objects WHERE id = :id AND status = 'CLEANUP_CLAIMED'")
                        .param("id", target.id())
                        .update();
                cleaned++;
            } else if (target.attempts() >= MAX_ATTEMPTS) {
                jdbc.sql("UPDATE media_objects SET status = 'FAILED' WHERE id = :id")
                        .param("id", target.id())
                        .update();
            } else {
                jdbc.sql("UPDATE media_objects SET next_attempt_at = :next WHERE id = :id")
                        .param("next", SqliteColumns.instant(now.plus(Duration.ofMinutes(1))))
                        .param("id", target.id())
                        .update();
            }
        }
        return cleaned;
    }

    private int cleanTombstones(Instant now) {
        List<CleanupTarget> pending = jdbc.sql("""
                SELECT id, object_key, attempt_count
                FROM media_cleanup_tombstones
                WHERE status IN ('PENDING', 'CLAIMED')
                  AND (next_attempt_at IS NULL OR next_attempt_at <= :now)
                """)
                .param("now", SqliteColumns.instant(now))
                .query((row, rowNumber) -> new CleanupTarget(
                        SqliteColumns.uuid(row, "id"),
                        row.getString("object_key"),
                        row.getInt("attempt_count"),
                        true))
                .list();
        int cleaned = 0;
        for (CleanupTarget target : pending) {
            jdbc.sql("""
                    UPDATE media_cleanup_tombstones
                    SET status = 'CLAIMED', attempt_count = attempt_count + 1
                    WHERE id = :id AND status IN ('PENDING', 'CLAIMED')
                    """)
                    .param("id", target.id())
                    .update();
            if (deleteObject(target)) {
                jdbc.sql("UPDATE media_cleanup_tombstones SET status = 'DONE' WHERE id = :id")
                        .param("id", target.id())
                        .update();
                cleaned++;
            } else if (target.attempts() + 1 >= MAX_ATTEMPTS) {
                jdbc.sql("UPDATE media_cleanup_tombstones SET status = 'TERMINAL' WHERE id = :id")
                        .param("id", target.id())
                        .update();
            } else {
                jdbc.sql("UPDATE media_cleanup_tombstones SET next_attempt_at = :next WHERE id = :id")
                        .param("next", SqliteColumns.instant(now.plus(Duration.ofMinutes(1))))
                        .param("id", target.id())
                        .update();
            }
        }
        return cleaned;
    }

    private boolean deleteObject(CleanupTarget target) {
        try {
            if (objects.exists(target.objectKey())) {
                objects.delete(target.objectKey());
            }
            return !objects.exists(target.objectKey());
        }
        catch (RuntimeException exception) {
            return false;
        }
    }

    private record CleanupTarget(UUID id, String objectKey, int attempts, boolean tombstone) {
    }
}
