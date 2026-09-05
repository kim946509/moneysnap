package com.ansandy.moneysnap.media;

import java.security.MessageDigest;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HexFormat;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

import com.ansandy.moneysnap.shared.SqliteColumns;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.support.TransactionTemplate;

final class MediaVault implements com.ansandy.moneysnap.shared.AccountMediaCleanup {

    static final int MAX_BYTES = 2_097_152;
    static final long STORAGE_LIMIT = 7_000_000_000L;
    static final int ROLLING_LIMIT = 20;

    private final JdbcClient jdbc;
    private final TransactionTemplate transactions;
    private final Clock clock;
    private final ObjectStore objects;

    MediaVault(JdbcClient jdbc, TransactionTemplate transactions, Clock clock, ObjectStore objects) {
        this.jdbc = Objects.requireNonNull(jdbc);
        this.transactions = Objects.requireNonNull(transactions);
        this.clock = Objects.requireNonNull(clock);
        this.objects = Objects.requireNonNull(objects);
    }

    MediaIntent createIntent(UUID ownerId, int declaredBytes, String contentType, String checksum) {
        if (declaredBytes < 1 || declaredBytes > MAX_BYTES) {
            throw new IllegalArgumentException("declared bytes out of range");
        }
        if (!"image/jpeg".equals(contentType)) {
            throw new IllegalArgumentException("content type must be image/jpeg");
        }
        if (checksum == null || !checksum.matches("^[0-9a-f]{64}$")) {
            throw new IllegalArgumentException("checksum must be sha-256 hex");
        }
        return transactions.execute(status -> createIntentInTransaction(ownerId, declaredBytes, checksum));
    }

    void upload(UUID ownerId, UUID mediaId, byte[] body) {
        MediaRow row = findOwned(ownerId, mediaId).orElseThrow(MediaNotAccessibleException::new);
        if (!"PENDING".equals(row.status()) || row.expiresAt().isBefore(clock.instant())) {
            throw new IllegalArgumentException("Upload intent is not usable");
        }
        if (body.length != row.declaredBytes()) {
            markFailed(mediaId);
            throw new IllegalArgumentException("Uploaded length does not match");
        }
        if (body.length > MAX_BYTES) {
            throw new IllegalArgumentException("Upload exceeds bound");
        }
        if (!sha256(body).equals(row.checksum())) {
            markFailed(mediaId);
            throw new IllegalArgumentException("Checksum mismatch");
        }
        objects.put(row.objectKey(), body);
    }

    MediaRef complete(UUID ownerId, UUID mediaId) {
        return transactions.execute(status -> completeInTransaction(ownerId, mediaId));
    }

    MediaReadGrant read(UUID actorId, UUID mediaId) {
        MediaRow row = findReadable(actorId, mediaId).orElseThrow(MediaNotAccessibleException::new);
        if (!"ACTIVE_UNLINKED".equals(row.status()) && !"LINKED".equals(row.status())) {
            throw new MediaNotAccessibleException();
        }
        if (!row.ownerId().equals(actorId) && !"LINKED".equals(row.status())) {
            throw new MediaNotAccessibleException();
        }
        byte[] bytes = objects.get(row.objectKey(), MAX_BYTES + 1);
        if (bytes == null) {
            throw new MediaNotAccessibleException();
        }
        return new MediaReadGrant(row.id(), bytes, clock.instant().plus(Duration.ofMinutes(10)));
    }

    void abort(UUID ownerId, UUID mediaId) {
        int claimed = jdbc.sql("""
                UPDATE media_objects
                SET status = 'CLEANUP_CLAIMED', attempt_count = attempt_count + 1
                WHERE id = :id AND owner_id = :ownerId AND status IN ('PENDING', 'ACTIVE_UNLINKED')
                """)
                .param("id", mediaId)
                .param("ownerId", ownerId)
                .update();
        if (claimed != 1) {
            throw new MediaNotAccessibleException();
        }
    }

    void scheduleCleanupForSnapImage(UUID ownerId, UUID snapId) {
        UUID imageId = jdbc.sql("SELECT image_id FROM snaps WHERE id = :id AND owner_id = :ownerId")
                .param("id", snapId)
                .param("ownerId", ownerId)
                .query(SqliteColumns::firstUuid)
                .optional()
                .orElse(null);
        if (imageId == null) {
            return;
        }
        jdbc.sql("""
                UPDATE media_objects
                SET status = 'CLEANUP_CLAIMED', attempt_count = attempt_count + 1
                WHERE id = :id AND owner_id = :ownerId AND status = 'LINKED'
                """)
                .param("id", imageId)
                .param("ownerId", ownerId)
                .update();
    }

    @Override
    public void transferToTombstones(UUID userId) {
        Instant now = clock.instant();
        transactions.executeWithoutResult(status -> {
            List<TombstoneSource> sources = jdbc.sql("""
                    SELECT object_key, declared_bytes
                    FROM media_objects
                    WHERE owner_id = :userId
                    """)
                    .param("userId", userId)
                    .query((row, rowNumber) -> new TombstoneSource(
                            row.getString("object_key"),
                            row.getInt("declared_bytes")))
                    .list();
            for (TombstoneSource source : sources) {
                jdbc.sql("""
                        INSERT INTO media_cleanup_tombstones (
                            id, object_key, declared_bytes, status, attempt_count, created_at
                        ) VALUES (:id, :objectKey, :declaredBytes, 'PENDING', 0, :now)
                        """)
                        .param("id", UUID.randomUUID())
                        .param("objectKey", source.objectKey())
                        .param("declaredBytes", source.declaredBytes())
                        .param("now", SqliteColumns.instant(now))
                        .update();
            }
        });
    }

    void claimForSnap(UUID ownerId, UUID mediaId, UUID snapId) {
        transactions.executeWithoutResult(status -> {
            int updated = jdbc.sql("""
                    UPDATE media_objects
                    SET status = 'LINKED'
                    WHERE id = :id AND owner_id = :ownerId AND status = 'ACTIVE_UNLINKED'
                      AND (orphan_expires_at IS NULL OR orphan_expires_at > :now)
                    """)
                    .param("id", mediaId)
                    .param("ownerId", ownerId)
                    .param("now", SqliteColumns.instant(clock.instant()))
                    .update();
            if (updated != 1) {
                throw new MediaNotAccessibleException();
            }
            jdbc.sql("UPDATE snaps SET image_id = :mediaId WHERE id = :snapId")
                    .param("mediaId", mediaId)
                    .param("snapId", snapId)
                    .update();
        });
    }

    private MediaIntent createIntentInTransaction(UUID ownerId, int declaredBytes, String checksum) {
        Instant now = clock.instant();
        Instant windowStart = now.minus(Duration.ofHours(24));
        int rolling = jdbc.sql("""
                SELECT count(*) FROM media_objects
                WHERE owner_id = :ownerId
                  AND (
                    (status IN ('ACTIVE_UNLINKED', 'LINKED') AND completed_at >= :windowStart)
                    OR (status = 'PENDING' AND expires_at > :now)
                  )
                """)
                .param("ownerId", ownerId)
                .param("windowStart", SqliteColumns.instant(windowStart))
                .param("now", SqliteColumns.instant(now))
                .query(Integer.class)
                .single();
        if (rolling >= ROLLING_LIMIT) {
            throw new MediaQuotaException();
        }
        long used = jdbc.sql("""
                SELECT coalesce(sum(declared_bytes), 0) FROM media_objects
                WHERE status IN ('PENDING', 'ACTIVE_UNLINKED', 'LINKED')
                  AND (status <> 'PENDING' OR expires_at > :now)
                """)
                .param("now", SqliteColumns.instant(now))
                .query(Long.class)
                .single();
        if (used + declaredBytes > STORAGE_LIMIT) {
            throw new MediaQuotaException();
        }
        UUID id = UUID.randomUUID();
        String key = "users/" + ownerId + "/" + id + ".jpg";
        Instant expiresAt = now.plus(Duration.ofMinutes(10));
        jdbc.sql("""
                INSERT INTO media_objects (
                    id, owner_id, object_key, content_type, declared_bytes, checksum_sha256,
                    status, expires_at, created_at
                ) VALUES (
                    :id, :ownerId, :objectKey, 'image/jpeg', :bytes, :checksum,
                    'PENDING', :expiresAt, :createdAt
                )
                """)
                .param("id", id)
                .param("ownerId", ownerId)
                .param("objectKey", key)
                .param("bytes", declaredBytes)
                .param("checksum", checksum)
                .param("expiresAt", SqliteColumns.instant(expiresAt))
                .param("createdAt", SqliteColumns.instant(now))
                .update();
        return new MediaIntent(id, "bounded-stream", "/api/v1/media/" + id + "/upload", expiresAt);
    }

    private MediaRef completeInTransaction(UUID ownerId, UUID mediaId) {
        MediaRow row = findOwned(ownerId, mediaId).orElseThrow(MediaNotAccessibleException::new);
        if (!"PENDING".equals(row.status())) {
            if ("ACTIVE_UNLINKED".equals(row.status()) || "LINKED".equals(row.status())) {
                return new MediaRef(row.id());
            }
            throw new IllegalArgumentException("Media cannot be completed");
        }
        byte[] bytes = objects.get(row.objectKey(), MAX_BYTES + 1);
        if (bytes == null || bytes.length != row.declaredBytes() || !sha256(bytes).equals(row.checksum())) {
            markFailed(mediaId);
            throw new IllegalArgumentException("Completed object failed verification");
        }
        if (bytes.length < 3 || bytes[0] != (byte) 0xFF || bytes[1] != (byte) 0xD8 || bytes[2] != (byte) 0xFF) {
            markFailed(mediaId);
            throw new IllegalArgumentException("JPEG signature required");
        }
        Instant now = clock.instant();
        jdbc.sql("""
                UPDATE media_objects
                SET status = 'ACTIVE_UNLINKED', completed_at = :now, orphan_expires_at = :orphan
                WHERE id = :id
                """)
                .param("now", SqliteColumns.instant(now))
                .param("orphan", SqliteColumns.instant(now.plus(Duration.ofHours(24))))
                .param("id", mediaId)
                .update();
        return new MediaRef(mediaId);
    }

    private Optional<MediaRow> findOwned(UUID ownerId, UUID mediaId) {
        return jdbc.sql("""
                SELECT id, owner_id, object_key, declared_bytes, checksum_sha256, status, expires_at
                FROM media_objects
                WHERE id = :id AND owner_id = :ownerId
                """)
                .param("id", mediaId)
                .param("ownerId", ownerId)
                .query(this::mapRow)
                .optional();
    }

    private Optional<MediaRow> findReadable(UUID actorId, UUID mediaId) {
        Optional<MediaRow> owned = findOwned(actorId, mediaId);
        if (owned.isPresent()) {
            return owned;
        }
        return jdbc.sql("""
                SELECT m.id, m.owner_id, m.object_key, m.declared_bytes, m.checksum_sha256, m.status, m.expires_at
                FROM media_objects m
                JOIN snaps s ON s.image_id = m.id
                JOIN snap_shares sh ON sh.snap_id = s.id
                JOIN group_memberships gm ON gm.group_id = sh.group_id AND gm.user_id = :actorId
                WHERE m.id = :id AND m.status = 'LINKED'
                LIMIT 1
                """)
                .param("id", mediaId)
                .param("actorId", actorId)
                .query(this::mapRow)
                .optional();
    }

    private MediaRow mapRow(java.sql.ResultSet row, int rowNumber) throws java.sql.SQLException {
        return new MediaRow(
                SqliteColumns.uuid(row, "id"),
                SqliteColumns.uuid(row, "owner_id"),
                row.getString("object_key"),
                row.getInt("declared_bytes"),
                row.getString("checksum_sha256"),
                row.getString("status"),
                SqliteColumns.instant(row, "expires_at") == null ? Instant.MAX : SqliteColumns.instant(row, "expires_at"));
    }

    private void markFailed(UUID mediaId) {
        jdbc.sql("UPDATE media_objects SET status = 'FAILED' WHERE id = :id")
                .param("id", mediaId)
                .update();
    }

    private static String sha256(byte[] bytes) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes));
        }
        catch (Exception exception) {
            throw new IllegalStateException(exception);
        }
    }

    private record MediaRow(
            UUID id,
            UUID ownerId,
            String objectKey,
            int declaredBytes,
            String checksum,
            String status,
            Instant expiresAt) {
    }

    private record TombstoneSource(String objectKey, int declaredBytes) {
    }
}

record MediaIntent(UUID imageRef, String mode, String uploadPath, Instant expiresAt) {
}

record MediaRef(UUID imageRef) {
}

record MediaReadGrant(UUID imageRef, byte[] bytes, Instant expiresAt) {
}

final class MediaNotAccessibleException extends RuntimeException {
}

final class MediaQuotaException extends RuntimeException {
}
