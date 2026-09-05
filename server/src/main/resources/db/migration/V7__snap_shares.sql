CREATE TABLE snap_shares (
    id TEXT PRIMARY KEY,
    snap_id TEXT NOT NULL REFERENCES snaps (id) ON DELETE CASCADE,
    group_id TEXT NOT NULL REFERENCES spend_groups (id) ON DELETE CASCADE,
    shared_at TEXT NOT NULL,
    CONSTRAINT snap_shares_unique UNIQUE (snap_id, group_id)
);

CREATE INDEX snap_shares_group_shared_at_idx ON snap_shares (group_id, shared_at DESC);

CREATE TABLE snap_share_mutations (
    owner_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    client_mutation_id TEXT NOT NULL,
    request_fingerprint TEXT NOT NULL,
    share_id TEXT,
    created_at TEXT NOT NULL,
    PRIMARY KEY (owner_id, client_mutation_id),
    CONSTRAINT snap_share_mutations_key_nonblank
        CHECK (length(trim(client_mutation_id)) > 0),
    CONSTRAINT snap_share_mutations_fingerprint_lower_hex
        CHECK (length(request_fingerprint) = 64)
);
