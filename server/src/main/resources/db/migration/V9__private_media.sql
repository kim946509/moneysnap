ALTER TABLE snaps ADD COLUMN image_id UUID;

CREATE TABLE media_objects (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    object_key VARCHAR(256) NOT NULL UNIQUE,
    content_type VARCHAR(64) NOT NULL,
    declared_bytes INTEGER NOT NULL,
    checksum_sha256 CHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL,
    expires_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    orphan_expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT media_objects_status CHECK (
        status IN ('PENDING', 'ACTIVE_UNLINKED', 'LINKED', 'FAILED', 'CLEANUP_CLAIMED')
    ),
    CONSTRAINT media_objects_checksum_hex CHECK (checksum_sha256 ~ '^[0-9a-f]{64}$'),
    CONSTRAINT media_objects_declared_bytes CHECK (declared_bytes BETWEEN 1 AND 2097152)
);

CREATE INDEX media_objects_owner_status_idx ON media_objects (owner_id, status);
ALTER TABLE snaps
    ADD CONSTRAINT snaps_image_id_fk FOREIGN KEY (image_id) REFERENCES media_objects (id);
