ALTER TABLE media_objects ADD COLUMN attempt_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE media_objects ADD COLUMN next_attempt_at TEXT;

CREATE TABLE media_cleanup_tombstones (
    id TEXT PRIMARY KEY,
    object_key TEXT NOT NULL,
    declared_bytes INTEGER NOT NULL,
    status TEXT NOT NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    next_attempt_at TEXT,
    created_at TEXT NOT NULL,
    CONSTRAINT media_cleanup_tombstones_status CHECK (
        status IN ('PENDING', 'CLAIMED', 'DONE', 'TERMINAL')
    )
);

CREATE INDEX media_cleanup_tombstones_status_idx
    ON media_cleanup_tombstones (status, next_attempt_at);
