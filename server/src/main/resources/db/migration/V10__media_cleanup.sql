ALTER TABLE media_objects ADD COLUMN attempt_count INTEGER NOT NULL DEFAULT 0;
ALTER TABLE media_objects ADD COLUMN next_attempt_at TIMESTAMPTZ;

CREATE TABLE media_cleanup_tombstones (
    id UUID PRIMARY KEY,
    object_key VARCHAR(256) NOT NULL,
    declared_bytes INTEGER NOT NULL,
    status VARCHAR(32) NOT NULL,
    attempt_count INTEGER NOT NULL DEFAULT 0,
    next_attempt_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT media_cleanup_tombstones_status CHECK (
        status IN ('PENDING', 'CLAIMED', 'DONE', 'TERMINAL')
    )
);

CREATE INDEX media_cleanup_tombstones_status_idx
    ON media_cleanup_tombstones (status, next_attempt_at);
