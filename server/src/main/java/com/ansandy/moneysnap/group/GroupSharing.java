package com.ansandy.moneysnap.group;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.sql.Date;
import java.sql.Timestamp;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.HexFormat;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.UUID;

import com.ansandy.moneysnap.shared.SqliteColumns;

import com.fasterxml.jackson.annotation.JsonInclude;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.transaction.support.TransactionTemplate;

final class GroupSharing {

    private final JdbcClient jdbc;
    private final TransactionTemplate transactions;
    private final Clock clock;

    GroupSharing(JdbcClient jdbc, TransactionTemplate transactions, Clock clock) {
        this.jdbc = Objects.requireNonNull(jdbc);
        this.transactions = Objects.requireNonNull(transactions);
        this.clock = Objects.requireNonNull(clock);
    }

    GroupRecord create(UUID ownerId, GroupCreateCommand command) {
        Objects.requireNonNull(ownerId, "ownerId");
        Objects.requireNonNull(command, "command");
        return transactions.execute(status -> createInTransaction(ownerId, command));
    }

    List<GroupRecord> list(UUID actorId) {
        Objects.requireNonNull(actorId, "actorId");
        return jdbc.sql("""
                SELECT g.id, g.name, g.amount_visible, m.role, g.created_at
                FROM spend_groups g
                JOIN group_memberships m ON m.group_id = g.id
                WHERE m.user_id = :actorId
                ORDER BY g.created_at DESC, g.id DESC
                """)
                .param("actorId", actorId)
                .query(this::mapGroup)
                .list();
    }

    GroupRecord get(UUID actorId, UUID groupId) {
        return findMembership(actorId, groupId).orElseThrow(GroupNotAccessibleException::new);
    }

    ShareRecord share(UUID actorId, ShareCommand command) {
        Objects.requireNonNull(actorId, "actorId");
        Objects.requireNonNull(command, "command");
        return transactions.execute(status -> shareInTransaction(actorId, command));
    }

    void delete(UUID actorId, UUID groupId, String clientMutationId) {
        Objects.requireNonNull(actorId, "actorId");
        Objects.requireNonNull(groupId, "groupId");
        transactions.executeWithoutResult(status -> deleteInTransaction(actorId, groupId, clientMutationId));
    }

    IssuedInvite issueInvite(UUID actorId, UUID groupId) {
        return transactions.execute(status -> issueInviteInTransaction(actorId, groupId));
    }

    void revokeInvite(UUID actorId, UUID groupId) {
        transactions.executeWithoutResult(status -> {
            requireOwner(actorId, groupId);
            Instant now = clock.instant();
            jdbc.sql("""
                    UPDATE group_invites SET revoked_at = :now
                    WHERE group_id = :groupId AND revoked_at IS NULL
                    """)
                    .param("now", SqliteColumns.instant(now))
                    .param("groupId", groupId)
                    .update();
        });
    }

    InvitePreview previewInvite(String rawCode) {
        InviteRow invite = findUsableInvite(rawCode).orElseThrow(GroupNotAccessibleException::new);
        GroupRecord group = findGroup(invite.groupId()).orElseThrow(GroupNotAccessibleException::new);
        return new InvitePreview(group.name(), group.amountVisible());
    }

    GroupRecord join(UUID actorId, String rawCode, String clientMutationId) {
        return transactions.execute(status -> joinInTransaction(actorId, rawCode, clientMutationId));
    }

    List<GroupMember> members(UUID actorId, UUID groupId) {
        findMembership(actorId, groupId).orElseThrow(GroupNotAccessibleException::new);
        return jdbc.sql("""
                SELECT m.user_id, u.display_name, m.role
                FROM group_memberships m
                JOIN users u ON u.id = m.user_id
                WHERE m.group_id = :groupId
                ORDER BY m.created_at ASC, m.user_id ASC
                """)
                .param("groupId", groupId)
                .query((row, rowNumber) -> new GroupMember(
                        SqliteColumns.uuid(row, "user_id"),
                        row.getString("display_name"),
                        avatarFor(row.getString("display_name")),
                        row.getString("role")))
                .list();
    }

    void leave(UUID actorId, UUID groupId) {
        transactions.executeWithoutResult(status -> {
            GroupRecord membership = findMembership(actorId, groupId).orElseThrow(GroupNotAccessibleException::new);
            if ("owner".equals(membership.role())) {
                throw new IllegalArgumentException("Owner cannot leave");
            }
            jdbc.sql("DELETE FROM group_memberships WHERE group_id = :groupId AND user_id = :userId")
                    .param("groupId", groupId)
                    .param("userId", actorId)
                    .update();
        });
    }

    void removeMember(UUID actorId, UUID groupId, UUID memberId) {
        transactions.executeWithoutResult(status -> {
            requireOwner(actorId, groupId);
            GroupRecord target = findMembership(memberId, groupId).orElseThrow(GroupNotAccessibleException::new);
            if ("owner".equals(target.role())) {
                throw new IllegalArgumentException("Owner cannot be removed");
            }
            jdbc.sql("DELETE FROM group_memberships WHERE group_id = :groupId AND user_id = :userId")
                    .param("groupId", groupId)
                    .param("userId", memberId)
                    .update();
        });
    }

    Object today(UUID actorId, UUID groupId, String timeZone) {
        GroupRecord membership = findMembership(actorId, groupId).orElseThrow(GroupNotAccessibleException::new);
        java.time.LocalDate day = java.time.LocalDate.ofInstant(
                clock.instant(), com.ansandy.moneysnap.shared.SnapTimeZones.requireRegionOrUtc(timeZone));
        List<MemberTodayRow> rows = memberTodayRows(groupId, day);
        if (membership.amountVisible()) {
            return new VisibleGroupToday(day, rows.stream().map(row -> new VisibleMemberToday(
                    row.userId(),
                    row.displayName(),
                    row.avatar(),
                    row.snapCount(),
                    row.totalAmountWon(),
                    row.representative() == null ? null : new VisibleSnap(
                            row.representative().snapId(),
                            row.representative().category(),
                            row.representative().amountWon(),
                            row.representative().sharedAt(),
                            row.representative().imageRef()
                    )
            )).toList());
        }
        return new HiddenGroupToday(day, rows.stream().map(row -> new HiddenMemberToday(
                row.userId(),
                row.displayName(),
                row.avatar(),
                row.snapCount(),
                row.representative() == null ? null : new HiddenSnap(
                        row.representative().snapId(),
                        row.representative().category(),
                        row.representative().sharedAt(),
                        row.representative().imageRef()
                )
        )).toList());
    }

    Object memberToday(UUID actorId, UUID groupId, UUID memberId, String timeZone) {
        findMembership(actorId, groupId).orElseThrow(GroupNotAccessibleException::new);
        findMembership(memberId, groupId).orElseThrow(GroupNotAccessibleException::new);
        Object groupToday = today(actorId, groupId, timeZone);
        if (groupToday instanceof VisibleGroupToday visible) {
            return visible.members().stream()
                    .filter(member -> member.userId().equals(memberId))
                    .findFirst()
                    .orElseThrow(GroupNotAccessibleException::new);
        }
        HiddenGroupToday hidden = (HiddenGroupToday) groupToday;
        return hidden.members().stream()
                .filter(member -> member.userId().equals(memberId))
                .findFirst()
                .orElseThrow(GroupNotAccessibleException::new);
    }

    private GroupRecord createInTransaction(UUID ownerId, GroupCreateCommand command) {
        String fingerprint = command.fingerprint();
        Instant now = clock.instant();
        int claimed = jdbc.sql("""
                INSERT INTO group_create_mutations (
                    owner_id, client_mutation_id, request_fingerprint, created_at
                ) VALUES (:ownerId, :mutationId, :fingerprint, :createdAt)
                ON CONFLICT (owner_id, client_mutation_id) DO NOTHING
                """)
                .param("ownerId", ownerId)
                .param("mutationId", command.clientMutationId())
                .param("fingerprint", fingerprint)
                .param("createdAt", SqliteColumns.instant(now))
                .update();
        if (claimed == 0) {
            CreateMutation existing = findCreateMutation(ownerId, command.clientMutationId()).orElseThrow();
            if (!existing.fingerprint().equals(fingerprint)) {
                throw new GroupMutationConflictException();
            }
            return findGroup(existing.groupId()).orElseThrow();
        }
        UUID groupId = UUID.randomUUID();
        jdbc.sql("""
                INSERT INTO spend_groups (id, owner_id, name, amount_visible, created_at)
                VALUES (:id, :ownerId, :name, :visible, :createdAt)
                """)
                .param("id", groupId)
                .param("ownerId", ownerId)
                .param("name", command.name().value())
                .param("visible", command.amountVisible())
                .param("createdAt", SqliteColumns.instant(now))
                .update();
        jdbc.sql("""
                INSERT INTO group_memberships (group_id, user_id, role, created_at)
                VALUES (:groupId, :userId, 'owner', :createdAt)
                """)
                .param("groupId", groupId)
                .param("userId", ownerId)
                .param("createdAt", SqliteColumns.instant(now))
                .update();
        jdbc.sql("""
                UPDATE group_create_mutations SET group_id = :groupId
                WHERE owner_id = :ownerId AND client_mutation_id = :mutationId
                """)
                .param("groupId", groupId)
                .param("ownerId", ownerId)
                .param("mutationId", command.clientMutationId())
                .update();
        return findGroup(groupId).orElseThrow();
    }

    private void deleteInTransaction(UUID actorId, UUID groupId, String clientMutationId) {
        GroupDeleteCommand command = new GroupDeleteCommand(clientMutationId, groupId);
        String fingerprint = command.fingerprint();
        Instant now = clock.instant();
        int claimed = jdbc.sql("""
                INSERT INTO group_delete_mutations (
                    owner_id, client_mutation_id, request_fingerprint, group_id, created_at
                ) VALUES (:ownerId, :mutationId, :fingerprint, :groupId, :createdAt)
                ON CONFLICT (owner_id, client_mutation_id) DO NOTHING
                """)
                .param("ownerId", actorId)
                .param("mutationId", command.clientMutationId())
                .param("fingerprint", fingerprint)
                .param("groupId", groupId)
                .param("createdAt", SqliteColumns.instant(now))
                .update();
        if (claimed == 0) {
            DeleteMutation existing = findDeleteMutation(actorId, command.clientMutationId()).orElseThrow();
            if (!existing.fingerprint().equals(fingerprint)) {
                throw new GroupMutationConflictException();
            }
            return;
        }
        GroupRecord membership = findMembership(actorId, groupId).orElseThrow(GroupNotAccessibleException::new);
        if (!"owner".equals(membership.role())) {
            throw new GroupNotAccessibleException();
        }
        jdbc.sql("DELETE FROM spend_groups WHERE id = :id AND owner_id = :ownerId")
                .param("id", groupId)
                .param("ownerId", actorId)
                .update();
    }

    private ShareRecord shareInTransaction(UUID actorId, ShareCommand command) {
        String fingerprint = command.fingerprint();
        Instant now = clock.instant();
        int claimed = jdbc.sql("""
                INSERT INTO snap_share_mutations (
                    owner_id, client_mutation_id, request_fingerprint, created_at
                ) VALUES (:ownerId, :mutationId, :fingerprint, :createdAt)
                ON CONFLICT (owner_id, client_mutation_id) DO NOTHING
                """)
                .param("ownerId", actorId)
                .param("mutationId", command.clientMutationId())
                .param("fingerprint", fingerprint)
                .param("createdAt", SqliteColumns.instant(now))
                .update();
        if (claimed == 0) {
            ShareMutation existing = findShareMutation(actorId, command.clientMutationId()).orElseThrow();
            if (!existing.fingerprint().equals(fingerprint)) {
                throw new GroupMutationConflictException();
            }
            return findShare(existing.shareId()).orElseThrow();
        }
        Integer owned = jdbc.sql("""
                SELECT count(*) FROM snaps WHERE id = :snapId AND owner_id = :ownerId
                """)
                .param("snapId", command.snapId())
                .param("ownerId", actorId)
                .query(Integer.class)
                .single();
        if (owned != 1 || findMembership(actorId, command.groupId()).isEmpty()) {
            throw new GroupNotAccessibleException();
        }
        UUID existingShare = jdbc.sql("""
                SELECT id FROM snap_shares WHERE snap_id = :snapId AND group_id = :groupId
                """)
                .param("snapId", command.snapId())
                .param("groupId", command.groupId())
                .query(SqliteColumns::firstUuid)
                .optional()
                .orElse(null);
        UUID shareId = existingShare == null ? UUID.randomUUID() : existingShare;
        if (existingShare == null) {
            jdbc.sql("""
                    INSERT INTO snap_shares (id, snap_id, group_id, shared_at)
                    VALUES (:id, :snapId, :groupId, :sharedAt)
                    """)
                    .param("id", shareId)
                    .param("snapId", command.snapId())
                    .param("groupId", command.groupId())
                    .param("sharedAt", SqliteColumns.instant(now))
                    .update();
        }
        jdbc.sql("""
                UPDATE snap_share_mutations SET share_id = :shareId
                WHERE owner_id = :ownerId AND client_mutation_id = :mutationId
                """)
                .param("shareId", shareId)
                .param("ownerId", actorId)
                .param("mutationId", command.clientMutationId())
                .update();
        return findShare(shareId).orElseThrow();
    }

    private Optional<ShareRecord> findShare(UUID shareId) {
        return jdbc.sql("""
                SELECT id, snap_id, group_id, shared_at FROM snap_shares WHERE id = :id
                """)
                .param("id", shareId)
                .query((row, rowNumber) -> new ShareRecord(
                        SqliteColumns.uuid(row, "id"),
                        SqliteColumns.uuid(row, "snap_id"),
                        SqliteColumns.uuid(row, "group_id"),
                        SqliteColumns.instant(row, "shared_at")))
                .optional();
    }

    private Optional<ShareMutation> findShareMutation(UUID ownerId, String mutationId) {
        return jdbc.sql("""
                SELECT request_fingerprint, share_id
                FROM snap_share_mutations
                WHERE owner_id = :ownerId AND client_mutation_id = :mutationId

                """)
                .param("ownerId", ownerId)
                .param("mutationId", mutationId)
                .query((row, rowNumber) -> new ShareMutation(
                        row.getString("request_fingerprint"),
                        SqliteColumns.uuid(row, "share_id")))
                .optional();
    }

    private IssuedInvite issueInviteInTransaction(UUID actorId, UUID groupId) {
        requireOwner(actorId, groupId);
        Instant now = clock.instant();
        jdbc.sql("""
                UPDATE group_invites SET revoked_at = :now
                WHERE group_id = :groupId AND revoked_at IS NULL
                """)
                .param("now", SqliteColumns.instant(now))
                .param("groupId", groupId)
                .update();
        byte[] secret = new byte[16];
        new SecureRandom().nextBytes(secret);
        String raw = HexFormat.of().formatHex(secret);
        UUID inviteId = UUID.randomUUID();
        Instant expiresAt = now.plus(Duration.ofHours(168));
        jdbc.sql("""
                INSERT INTO group_invites (id, group_id, token_hash, issued_at, expires_at)
                VALUES (:id, :groupId, :hash, :issuedAt, :expiresAt)
                """)
                .param("id", inviteId)
                .param("groupId", groupId)
                .param("hash", sha256(raw))
                .param("issuedAt", SqliteColumns.instant(now))
                .param("expiresAt", SqliteColumns.instant(expiresAt))
                .update();
        return new IssuedInvite(raw, expiresAt);
    }

    private GroupRecord joinInTransaction(UUID actorId, String rawCode, String clientMutationId) {
        if (clientMutationId == null || clientMutationId.isBlank()
                || clientMutationId.codePointCount(0, clientMutationId.length()) > 128) {
            throw new IllegalArgumentException("clientMutationId must be 1 to 128 nonblank characters");
        }
        String fingerprint = sha256("group-join:v1\ncode=%s".formatted(rawCode));
        Instant now = clock.instant();
        int claimed = jdbc.sql("""
                INSERT INTO group_join_mutations (
                    owner_id, client_mutation_id, request_fingerprint, created_at
                ) VALUES (:ownerId, :mutationId, :fingerprint, :createdAt)
                ON CONFLICT (owner_id, client_mutation_id) DO NOTHING
                """)
                .param("ownerId", actorId)
                .param("mutationId", clientMutationId)
                .param("fingerprint", fingerprint)
                .param("createdAt", SqliteColumns.instant(now))
                .update();
        if (claimed == 0) {
            JoinMutation existing = jdbc.sql("""
                    SELECT request_fingerprint, group_id
                    FROM group_join_mutations
                    WHERE owner_id = :ownerId AND client_mutation_id = :mutationId
                    """)
                    .param("ownerId", actorId)
                    .param("mutationId", clientMutationId)
                    .query((row, rowNumber) -> new JoinMutation(
                            row.getString("request_fingerprint"),
                            SqliteColumns.uuid(row, "group_id")))
                    .optional()
                    .orElseThrow();
            if (!existing.fingerprint().equals(fingerprint)) {
                throw new GroupMutationConflictException();
            }
            return findMembership(actorId, existing.groupId()).orElseThrow();
        }
        InviteRow invite = findUsableInvite(rawCode).orElseThrow(GroupNotAccessibleException::new);
        Optional<GroupRecord> already = findMembership(actorId, invite.groupId());
        if (already.isPresent()) {
            jdbc.sql("""
                    UPDATE group_join_mutations SET group_id = :groupId
                    WHERE owner_id = :ownerId AND client_mutation_id = :mutationId
                    """)
                    .param("groupId", invite.groupId())
                    .param("ownerId", actorId)
                    .param("mutationId", clientMutationId)
                    .update();
            return already.get();
        }
        int count = jdbc.sql("SELECT count(*) FROM group_memberships WHERE group_id = :groupId")
                .param("groupId", invite.groupId())
                .query(Integer.class)
                .single();
        if (count >= 20) {
            throw new IllegalArgumentException("Group is full");
        }
        jdbc.sql("""
                INSERT INTO group_memberships (group_id, user_id, role, created_at)
                VALUES (:groupId, :userId, 'member', :createdAt)
                """)
                .param("groupId", invite.groupId())
                .param("userId", actorId)
                .param("createdAt", SqliteColumns.instant(now))
                .update();
        jdbc.sql("""
                UPDATE group_join_mutations SET group_id = :groupId
                WHERE owner_id = :ownerId AND client_mutation_id = :mutationId
                """)
                .param("groupId", invite.groupId())
                .param("ownerId", actorId)
                .param("mutationId", clientMutationId)
                .update();
        return findMembership(actorId, invite.groupId()).orElseThrow();
    }

    private Optional<InviteRow> findUsableInvite(String rawCode) {
        if (rawCode == null || rawCode.isBlank()) {
            return Optional.empty();
        }
        Instant now = clock.instant();
        return jdbc.sql("""
                SELECT id, group_id, expires_at
                FROM group_invites
                WHERE token_hash = :hash AND revoked_at IS NULL AND expires_at > :now
                """)
                .param("hash", sha256(rawCode))
                .param("now", SqliteColumns.instant(now))
                .query((row, rowNumber) -> new InviteRow(
                        SqliteColumns.uuid(row, "id"),
                        SqliteColumns.uuid(row, "group_id"),
                        SqliteColumns.instant(row, "expires_at")))
                .optional();
    }

    private void requireOwner(UUID actorId, UUID groupId) {
        GroupRecord membership = findMembership(actorId, groupId).orElseThrow(GroupNotAccessibleException::new);
        if (!"owner".equals(membership.role())) {
            throw new GroupNotAccessibleException();
        }
    }

    private List<MemberTodayRow> memberTodayRows(UUID groupId, java.time.LocalDate day) {
        List<GroupMember> members = jdbc.sql("""
                SELECT m.user_id, u.display_name, m.role
                FROM group_memberships m
                JOIN users u ON u.id = m.user_id
                WHERE m.group_id = :groupId
                ORDER BY m.created_at ASC, m.user_id ASC
                """)
                .param("groupId", groupId)
                .query((row, rowNumber) -> new GroupMember(
                        SqliteColumns.uuid(row, "user_id"),
                        row.getString("display_name"),
                        avatarFor(row.getString("display_name")),
                        row.getString("role")))
                .list();
        List<MemberTodayRow> rows = new ArrayList<>();
        for (GroupMember member : members) {
            int snapCount = jdbc.sql("""
                    SELECT count(*)
                    FROM snap_shares sh
                    JOIN snaps s ON s.id = sh.snap_id
                    WHERE sh.group_id = :groupId AND s.owner_id = :ownerId AND s.local_day = :day
                    """)
                    .param("groupId", groupId)
                    .param("ownerId", member.userId())
                    .param("day", day.toString())
                    .query(Integer.class)
                    .single();
            Long total = jdbc.sql("""
                    SELECT coalesce(sum(s.amount_won), 0)
                    FROM snap_shares sh
                    JOIN snaps s ON s.id = sh.snap_id
                    WHERE sh.group_id = :groupId AND s.owner_id = :ownerId AND s.local_day = :day
                    """)
                    .param("groupId", groupId)
                    .param("ownerId", member.userId())
                    .param("day", day.toString())
                    .query(Long.class)
                    .single();
            RepresentativeSnap representative = jdbc.sql("""
                    SELECT s.id, s.category, s.amount_won, sh.shared_at, s.image_id
                    FROM snap_shares sh
                    JOIN snaps s ON s.id = sh.snap_id
                    WHERE sh.group_id = :groupId AND s.owner_id = :ownerId AND s.local_day = :day
                    ORDER BY sh.shared_at DESC, sh.id DESC
                    LIMIT 1
                    """)
                    .param("groupId", groupId)
                    .param("ownerId", member.userId())
                    .param("day", day.toString())
                    .query((row, rowNumber) -> new RepresentativeSnap(
                            SqliteColumns.uuid(row, "id"),
                            row.getString("category"),
                            row.getLong("amount_won"),
                            SqliteColumns.instant(row, "shared_at"),
                            SqliteColumns.uuid(row, "image_id")))
                    .optional()
                    .orElse(null);
            rows.add(new MemberTodayRow(
                    member.userId(),
                    member.displayName(),
                    member.avatar(),
                    snapCount,
                    total,
                    representative));
        }
        return rows;
    }

    private static String avatarFor(String displayName) {
        if (displayName == null || displayName.isBlank()) {
            return "₩";
        }
        return displayName.substring(0, displayName.offsetByCodePoints(0, 1));
    }

    private static String sha256(String value) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(value.getBytes(StandardCharsets.UTF_8)));
        }
        catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }

    private Optional<GroupRecord> findMembership(UUID actorId, UUID groupId) {
        return jdbc.sql("""
                SELECT g.id, g.name, g.amount_visible, m.role, g.created_at
                FROM spend_groups g
                JOIN group_memberships m ON m.group_id = g.id
                WHERE g.id = :groupId AND m.user_id = :actorId
                """)
                .param("groupId", groupId)
                .param("actorId", actorId)
                .query(this::mapGroup)
                .optional();
    }

    private Optional<GroupRecord> findGroup(UUID groupId) {
        return jdbc.sql("""
                SELECT g.id, g.name, g.amount_visible, 'owner' AS role, g.created_at
                FROM spend_groups g
                WHERE g.id = :groupId
                """)
                .param("groupId", groupId)
                .query(this::mapGroup)
                .optional();
    }

    private Optional<CreateMutation> findCreateMutation(UUID ownerId, String mutationId) {
        return jdbc.sql("""
                SELECT request_fingerprint, group_id
                FROM group_create_mutations
                WHERE owner_id = :ownerId AND client_mutation_id = :mutationId

                """)
                .param("ownerId", ownerId)
                .param("mutationId", mutationId)
                .query((row, rowNumber) -> new CreateMutation(
                        row.getString("request_fingerprint"),
                        SqliteColumns.uuid(row, "group_id")))
                .optional();
    }

    private Optional<DeleteMutation> findDeleteMutation(UUID ownerId, String mutationId) {
        return jdbc.sql("""
                SELECT request_fingerprint, group_id
                FROM group_delete_mutations
                WHERE owner_id = :ownerId AND client_mutation_id = :mutationId

                """)
                .param("ownerId", ownerId)
                .param("mutationId", mutationId)
                .query((row, rowNumber) -> new DeleteMutation(
                        row.getString("request_fingerprint"),
                        SqliteColumns.uuid(row, "group_id")))
                .optional();
    }

    private GroupRecord mapGroup(java.sql.ResultSet row, int rowNumber) throws java.sql.SQLException {
        return new GroupRecord(
                SqliteColumns.uuid(row, "id"),
                row.getString("name"),
                row.getBoolean("amount_visible"),
                row.getString("role"),
                SqliteColumns.instant(row, "created_at"));
    }

    private record CreateMutation(String fingerprint, UUID groupId) {
    }

    private record DeleteMutation(String fingerprint, UUID groupId) {
    }

    private record ShareMutation(String fingerprint, UUID shareId) {
    }

    private record InviteRow(UUID id, UUID groupId, Instant expiresAt) {
    }

    private record JoinMutation(String fingerprint, UUID groupId) {
    }

    private record RepresentativeSnap(
            UUID snapId, String category, long amountWon, Instant sharedAt, UUID imageRef) {
    }

    private record MemberTodayRow(
            UUID userId,
            String displayName,
            String avatar,
            int snapCount,
            long totalAmountWon,
            RepresentativeSnap representative) {
    }
}

record IssuedInvite(String code, Instant expiresAt) {
}

record InvitePreview(String name, boolean amountVisible) {
}

record GroupMember(UUID userId, String displayName, String avatar, String role) {
}

record VisibleGroupToday(java.time.LocalDate localDay, List<VisibleMemberToday> members) {
}

record VisibleMemberToday(
        UUID userId,
        String displayName,
        String avatar,
        int snapCount,
        long totalAmountWon,
        VisibleSnap representative) {
}

@JsonInclude(JsonInclude.Include.NON_NULL)
record VisibleSnap(UUID snapId, String category, long amountWon, Instant sharedAt, UUID imageRef) {
}

record HiddenGroupToday(java.time.LocalDate localDay, List<HiddenMemberToday> members) {
}

record HiddenMemberToday(
        UUID userId,
        String displayName,
        String avatar,
        int snapCount,
        HiddenSnap representative) {
}

@JsonInclude(JsonInclude.Include.NON_NULL)
record HiddenSnap(UUID snapId, String category, Instant sharedAt, UUID imageRef) {
}

record ShareCommand(String clientMutationId, UUID snapId, UUID groupId) {

    ShareCommand {
        if (clientMutationId == null || clientMutationId.isBlank()
                || clientMutationId.codePointCount(0, clientMutationId.length()) > 128) {
            throw new IllegalArgumentException("clientMutationId must be 1 to 128 nonblank characters");
        }
        Objects.requireNonNull(snapId, "snapId");
        Objects.requireNonNull(groupId, "groupId");
    }

    String fingerprint() {
        String payload = "snap-share:v1\nsnapId=%s\ngroupId=%s".formatted(snapId, groupId);
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(payload.getBytes(StandardCharsets.UTF_8)));
        }
        catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }
}

record ShareRecord(UUID id, UUID snapId, UUID groupId, Instant sharedAt) {
}

record GroupCreateCommand(String clientMutationId, GroupName name, boolean amountVisible) {

    GroupCreateCommand {
        if (clientMutationId == null || clientMutationId.isBlank()
                || clientMutationId.codePointCount(0, clientMutationId.length()) > 128) {
            throw new IllegalArgumentException("clientMutationId must be 1 to 128 nonblank characters");
        }
        Objects.requireNonNull(name, "name");
    }

    String fingerprint() {
        String payload = "group-create:v1\nname=%s\namountVisible=%s".formatted(name.value(), amountVisible);
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(payload.getBytes(StandardCharsets.UTF_8)));
        }
        catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }
}

record GroupDeleteCommand(String clientMutationId, UUID groupId) {

    GroupDeleteCommand {
        if (clientMutationId == null || clientMutationId.isBlank()
                || clientMutationId.codePointCount(0, clientMutationId.length()) > 128) {
            throw new IllegalArgumentException("clientMutationId must be 1 to 128 nonblank characters");
        }
        Objects.requireNonNull(groupId, "groupId");
    }

    String fingerprint() {
        String payload = "group-delete:v1\ngroupId=%s".formatted(groupId);
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256")
                    .digest(payload.getBytes(StandardCharsets.UTF_8)));
        }
        catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }
}

record GroupRecord(UUID id, String name, boolean amountVisible, String role, Instant createdAt) {
}

record GroupList(List<GroupRecord> groups) {
}

record MemberList(List<GroupMember> members) {
}

final class GroupMutationConflictException extends RuntimeException {
}

final class GroupNotAccessibleException extends RuntimeException {
}
