ALTER TABLE users ADD COLUMN display_name VARCHAR(128) NOT NULL DEFAULT 'MoneySnap 사용자';

CREATE TABLE spend_groups (
    id UUID PRIMARY KEY,
    owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name VARCHAR(120) NOT NULL,
    amount_visible BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE INDEX spend_groups_owner_id_idx ON spend_groups (owner_id);

CREATE TABLE group_memberships (
    group_id UUID NOT NULL REFERENCES spend_groups (id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role VARCHAR(16) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (group_id, user_id),
    CONSTRAINT group_memberships_role CHECK (role IN ('owner', 'member'))
);

CREATE UNIQUE INDEX group_memberships_one_owner_idx
    ON group_memberships (group_id)
    WHERE role = 'owner';

CREATE TABLE group_create_mutations (
    owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    client_mutation_id VARCHAR(128) NOT NULL,
    request_fingerprint CHAR(64) NOT NULL,
    group_id UUID,
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (owner_id, client_mutation_id),
    CONSTRAINT group_create_mutations_key_nonblank
        CHECK (length(btrim(client_mutation_id)) > 0),
    CONSTRAINT group_create_mutations_fingerprint_lower_hex
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$')
);

CREATE TABLE group_delete_mutations (
    owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    client_mutation_id VARCHAR(128) NOT NULL,
    request_fingerprint CHAR(64) NOT NULL,
    group_id UUID NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (owner_id, client_mutation_id),
    CONSTRAINT group_delete_mutations_key_nonblank
        CHECK (length(btrim(client_mutation_id)) > 0),
    CONSTRAINT group_delete_mutations_fingerprint_lower_hex
        CHECK (request_fingerprint ~ '^[0-9a-f]{64}$')
);

CREATE TABLE group_invites (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES spend_groups (id) ON DELETE CASCADE,
    token_hash CHAR(64) NOT NULL UNIQUE,
    issued_at TIMESTAMPTZ NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    CONSTRAINT group_invites_hash_lower_hex
        CHECK (token_hash ~ '^[0-9a-f]{64}$')
);

CREATE UNIQUE INDEX group_invites_one_active_idx
    ON group_invites (group_id)
    WHERE revoked_at IS NULL;
