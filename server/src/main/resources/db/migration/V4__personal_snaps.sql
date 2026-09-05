CREATE TABLE snaps (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    category TEXT NOT NULL,
    amount_won INTEGER NOT NULL,
    local_day TEXT NOT NULL,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    version INTEGER NOT NULL,
    CONSTRAINT snaps_category CHECK (
        category IN ('food', 'cafe', 'transportation', 'shopping',
                     'living', 'culture', 'health', 'other')
    ),
    CONSTRAINT snaps_amount_won CHECK (amount_won BETWEEN 1 AND 999999999),
    CONSTRAINT snaps_version_positive CHECK (version >= 1)
);

CREATE INDEX snaps_owner_local_day_idx ON snaps (owner_id, local_day);

CREATE TABLE snap_record_mutations (
    owner_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    client_mutation_id TEXT NOT NULL,
    request_fingerprint TEXT NOT NULL,
    snap_id TEXT,
    created_at TEXT NOT NULL,
    PRIMARY KEY (owner_id, client_mutation_id),
    CONSTRAINT snap_record_mutations_key_nonblank
        CHECK (length(trim(client_mutation_id)) > 0),
    CONSTRAINT snap_record_mutations_fingerprint_lower_hex
        CHECK (length(request_fingerprint) = 64)
);

CREATE UNIQUE INDEX snap_record_mutations_snap_id_idx
    ON snap_record_mutations (snap_id);
