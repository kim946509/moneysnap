CREATE TABLE group_join_mutations (
    owner_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    client_mutation_id TEXT NOT NULL,
    request_fingerprint TEXT NOT NULL,
    group_id TEXT,
    created_at TEXT NOT NULL,
    PRIMARY KEY (owner_id, client_mutation_id),
    CONSTRAINT group_join_mutations_key_nonblank
        CHECK (length(trim(client_mutation_id)) > 0),
    CONSTRAINT group_join_mutations_fingerprint_lower_hex
        CHECK (length(request_fingerprint) = 64)
);
