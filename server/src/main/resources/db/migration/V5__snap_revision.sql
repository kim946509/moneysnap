CREATE TABLE snap_revise_mutations (
    owner_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    client_mutation_id TEXT NOT NULL,
    request_fingerprint TEXT NOT NULL,
    snap_id TEXT NOT NULL,
    category TEXT NOT NULL,
    amount_won INTEGER NOT NULL,
    local_day TEXT NOT NULL,
    snap_created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    version INTEGER NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY (owner_id, client_mutation_id),
    CONSTRAINT snap_revise_mutations_key_nonblank
        CHECK (length(trim(client_mutation_id)) > 0),
    CONSTRAINT snap_revise_mutations_fingerprint_lower_hex
        CHECK (length(request_fingerprint) = 64)
);

CREATE TABLE snap_delete_mutations (
    owner_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    client_mutation_id TEXT NOT NULL,
    request_fingerprint TEXT NOT NULL,
    snap_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY (owner_id, client_mutation_id),
    CONSTRAINT snap_delete_mutations_key_nonblank
        CHECK (length(trim(client_mutation_id)) > 0),
    CONSTRAINT snap_delete_mutations_fingerprint_lower_hex
        CHECK (length(request_fingerprint) = 64)
);
