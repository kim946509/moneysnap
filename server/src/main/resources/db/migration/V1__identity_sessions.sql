CREATE TABLE users (
    id TEXT PRIMARY KEY,
    created_at TEXT NOT NULL
);

CREATE TABLE apple_identities (
    user_id TEXT PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    apple_subject TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE identity_sessions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    access_token_hash TEXT NOT NULL UNIQUE,
    access_expires_at TEXT NOT NULL,
    refresh_expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    last_used_at TEXT NOT NULL,
    revoked_at TEXT,
    CONSTRAINT identity_sessions_access_hash_lower_hex
        CHECK (length(access_token_hash) = 64)
);

CREATE INDEX identity_sessions_user_id_idx ON identity_sessions (user_id);

CREATE TABLE identity_refresh_tokens (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL REFERENCES identity_sessions (id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    created_at TEXT NOT NULL,
    used_at TEXT,
    CONSTRAINT identity_refresh_tokens_status
        CHECK (status IN ('ACTIVE', 'USED')),
    CONSTRAINT identity_refresh_tokens_hash_lower_hex
        CHECK (length(token_hash) = 64),
    CONSTRAINT identity_refresh_tokens_used_at
        CHECK ((status = 'ACTIVE' AND used_at IS NULL) OR (status = 'USED' AND used_at IS NOT NULL))
);

CREATE INDEX identity_refresh_tokens_session_id_idx ON identity_refresh_tokens (session_id);
CREATE UNIQUE INDEX identity_refresh_tokens_one_active_per_session_idx
    ON identity_refresh_tokens (session_id)
    WHERE status = 'ACTIVE';
