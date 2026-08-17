ALTER TABLE snaps ADD COLUMN updated_at TIMESTAMPTZ;
ALTER TABLE snaps ADD COLUMN version INTEGER;

UPDATE snaps SET updated_at = created_at, version = 1 WHERE updated_at IS NULL;

ALTER TABLE snaps ALTER COLUMN updated_at SET NOT NULL;
ALTER TABLE snaps ALTER COLUMN version SET NOT NULL;
ALTER TABLE snaps ADD CONSTRAINT snaps_version_positive CHECK (version >= 1);

CREATE TABLE snap_revise_mutations (
    owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    client_mutation_id VARCHAR(128) NOT NULL,
    request_fingerprint CHAR(64) NOT NULL,
    snap_id UUID NOT NULL,
    category VARCHAR(16) NOT NULL,
    amount_won INTEGER NOT NULL,
    local_day DATE NOT NULL,
    snap_created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL,
    version INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (owner_id, client_mutation_id),
    CONSTRAINT snap_revise_mutations_key_nonblank
        CHECK (length(btrim(client_mutation_id)) > 0),
    CONSTRAINT snap_revise_mutations_fingerprint_lower_hex
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$')
);

CREATE TABLE snap_delete_mutations (
    owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    client_mutation_id VARCHAR(128) NOT NULL,
    request_fingerprint CHAR(64) NOT NULL,
    snap_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (owner_id, client_mutation_id),
    CONSTRAINT snap_delete_mutations_key_nonblank
        CHECK (length(btrim(client_mutation_id)) > 0),
    CONSTRAINT snap_delete_mutations_fingerprint_lower_hex
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$')
);
