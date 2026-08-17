CREATE TABLE group_join_mutations (
    owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    client_mutation_id VARCHAR(128) NOT NULL,
    request_fingerprint CHAR(64) NOT NULL,
    group_id UUID,
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (owner_id, client_mutation_id),
    CONSTRAINT group_join_mutations_key_nonblank
        CHECK (length(btrim(client_mutation_id)) > 0),
    CONSTRAINT group_join_mutations_fingerprint_lower_hex
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$')
);
