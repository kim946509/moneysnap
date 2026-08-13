CREATE TABLE snaps (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    category VARCHAR(16) NOT NULL,
    amount_won INTEGER NOT NULL,
    local_day DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT snaps_category CHECK (
        category IN ('food', 'cafe', 'transportation', 'shopping',
                     'living', 'culture', 'health', 'other')
    ),
    CONSTRAINT snaps_amount_won CHECK (amount_won BETWEEN 1 AND 999999999)
);

CREATE INDEX snaps_owner_local_day_idx ON snaps (owner_id, local_day);

CREATE TABLE snap_record_mutations (
    owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    client_mutation_id VARCHAR(128) NOT NULL,
    request_fingerprint CHAR(64) NOT NULL,
    snap_id UUID,
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (owner_id, client_mutation_id),
    CONSTRAINT snap_record_mutations_key_nonblank
        CHECK (length(btrim(client_mutation_id)) > 0),
    CONSTRAINT snap_record_mutations_fingerprint_lower_hex
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$')
);

CREATE UNIQUE INDEX snap_record_mutations_snap_id_idx
    ON snap_record_mutations (snap_id);
