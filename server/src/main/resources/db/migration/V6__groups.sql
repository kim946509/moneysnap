ALTER TABLE users ADD COLUMN display_name TEXT NOT NULL DEFAULT 'MoneySnap 사용자';

CREATE TABLE spend_groups (
    id TEXT PRIMARY KEY,
    owner_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    amount_visible INTEGER NOT NULL,
    created_at TEXT NOT NULL
);

CREATE INDEX spend_groups_owner_id_idx ON spend_groups (owner_id);

CREATE TABLE group_memberships (
    group_id TEXT NOT NULL REFERENCES spend_groups (id) ON DELETE CASCADE,
    user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    role TEXT NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY (group_id, user_id),
    CONSTRAINT group_memberships_role CHECK (role IN ('owner', 'member'))
);

CREATE UNIQUE INDEX group_memberships_one_owner_idx
    ON group_memberships (group_id)
    WHERE role = 'owner';

CREATE TABLE group_create_mutations (
    owner_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    client_mutation_id TEXT NOT NULL,
    request_fingerprint TEXT NOT NULL,
    group_id TEXT,
    created_at TEXT NOT NULL,
    PRIMARY KEY (owner_id, client_mutation_id),
    CONSTRAINT group_create_mutations_key_nonblank
        CHECK (length(trim(client_mutation_id)) > 0),
    CONSTRAINT group_create_mutations_fingerprint_lower_hex
        CHECK (length(request_fingerprint) = 64)
);

CREATE TABLE group_delete_mutations (
    owner_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    client_mutation_id TEXT NOT NULL,
    request_fingerprint TEXT NOT NULL,
    group_id TEXT NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY (owner_id, client_mutation_id),
    CONSTRAINT group_delete_mutations_key_nonblank
        CHECK (length(trim(client_mutation_id)) > 0),
    CONSTRAINT group_delete_mutations_fingerprint_lower_hex
        CHECK (length(request_fingerprint) = 64)
);

CREATE TABLE group_invites (
    id TEXT PRIMARY KEY,
    group_id TEXT NOT NULL REFERENCES spend_groups (id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    issued_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    revoked_at TEXT,
    CONSTRAINT group_invites_hash_lower_hex
        CHECK (length(token_hash) = 64)
);

CREATE UNIQUE INDEX group_invites_one_active_idx
    ON group_invites (group_id)
    WHERE revoked_at IS NULL;
