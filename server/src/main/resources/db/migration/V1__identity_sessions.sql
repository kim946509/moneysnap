CREATE TABLE users (
    id UUID PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE apple_identities (
    user_id UUID PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    apple_subject VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL
);

CREATE TABLE identity_sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    access_token_hash CHAR(64) NOT NULL UNIQUE,
    access_expires_at TIMESTAMPTZ NOT NULL,
    refresh_expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    last_used_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    CONSTRAINT identity_sessions_access_hash_lower_hex
        CHECK (access_token_hash ~ '^[0-9a-f]{64}$')
);

CREATE INDEX identity_sessions_user_id_idx ON identity_sessions (user_id);

CREATE TABLE identity_refresh_tokens (
    id UUID PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES identity_sessions (id) ON DELETE CASCADE,
    token_hash CHAR(64) NOT NULL UNIQUE,
    status VARCHAR(16) NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    CONSTRAINT identity_refresh_tokens_status
        CHECK (status IN ('ACTIVE', 'USED')),
    CONSTRAINT identity_refresh_tokens_hash_lower_hex
        CHECK (token_hash ~ '^[0-9a-f]{64}$'),
    CONSTRAINT identity_refresh_tokens_used_at
        CHECK ((status = 'ACTIVE' AND used_at IS NULL) OR (status = 'USED' AND used_at IS NOT NULL))
);

CREATE INDEX identity_refresh_tokens_session_id_idx ON identity_refresh_tokens (session_id);
CREATE UNIQUE INDEX identity_refresh_tokens_one_active_per_session_idx
    ON identity_refresh_tokens (session_id)
    WHERE status = 'ACTIVE';
