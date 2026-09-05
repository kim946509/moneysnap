CREATE TABLE media_objects (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    object_key TEXT NOT NULL UNIQUE,
    content_type TEXT NOT NULL,
    declared_bytes INTEGER NOT NULL,
    checksum_sha256 TEXT NOT NULL,
    status TEXT NOT NULL,
    expires_at TEXT,
    completed_at TEXT,
    orphan_expires_at TEXT,
    created_at TEXT NOT NULL,
    CONSTRAINT media_objects_status CHECK (
        status IN ('PENDING', 'ACTIVE_UNLINKED', 'LINKED', 'FAILED', 'CLEANUP_CLAIMED')
    ),
    CONSTRAINT media_objects_checksum_hex CHECK (length(checksum_sha256) = 64),
    CONSTRAINT media_objects_declared_bytes CHECK (declared_bytes BETWEEN 1 AND 2097152)
);

CREATE INDEX media_objects_owner_status_idx ON media_objects (owner_id, status);

ALTER TABLE snaps ADD COLUMN image_id TEXT;
