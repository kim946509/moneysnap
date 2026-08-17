CREATE TABLE snap_shares (
    id UUID PRIMARY KEY,
    snap_id UUID NOT NULL REFERENCES snaps (id) ON DELETE CASCADE,
    group_id UUID NOT NULL REFERENCES spend_groups (id) ON DELETE CASCADE,
    shared_at TIMESTAMPTZ NOT NULL,
    CONSTRAINT snap_shares_unique UNIQUE (snap_id, group_id)
);

CREATE INDEX snap_shares_group_shared_at_idx ON snap_shares (group_id, shared_at DESC);

CREATE TABLE snap_share_mutations (
    owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    client_mutation_id VARCHAR(128) NOT NULL,
    request_fingerprint CHAR(64) NOT NULL,
    share_id UUID,
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (owner_id, client_mutation_id),
    CONSTRAINT snap_share_mutations_key_nonblank
        CHECK (length(btrim(client_mutation_id)) > 0),
    CONSTRAINT snap_share_mutations_fingerprint_lower_hex
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$')
);
