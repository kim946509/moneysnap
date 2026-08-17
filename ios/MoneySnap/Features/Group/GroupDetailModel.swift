import Foundation
import Observation

@MainActor
@Observable
final class GroupDetailModel {
    let group: MoneySnapGroup
    private(set) var members: [GroupMember] = []
    private(set) var inviteCode: String?
    private(set) var joinPreview: InvitePreview?
    private(set) var pendingJoinCode: String?
    private(set) var visibleMembers: [VisibleMemberToday] = []
    private(set) var hiddenMembers: [HiddenMemberToday] = []
    private(set) var failed = false
    private let client: any GroupClient
    private let mutationID: @Sendable () -> UUID

    init(
        group: MoneySnapGroup,
        client: any GroupClient,
        mutationID: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.group = group
        self.client = client
        self.mutationID = mutationID
    }

    func load() async {
        do {
            members = try await client.members(groupID: group.id).members
            if group.amountVisible {
                visibleMembers = try await client.visibleToday(groupID: group.id).members
            } else {
                hiddenMembers = try await client.hiddenToday(groupID: group.id).members
            }
            failed = false
        } catch {
            failed = true
        }
    }

    func issueInvite() async {
        inviteCode = try? await client.issueInvite(groupID: group.id).code
    }

    func revokeInvite() async {
        do {
            try await client.revokeInvite(groupID: group.id)
            inviteCode = nil
        } catch {
            failed = true
        }
    }

    func previewInvite(code: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            joinPreview = try await client.preview(code: trimmed)
            pendingJoinCode = trimmed
            failed = false
        } catch {
            joinPreview = nil
            pendingJoinCode = nil
            failed = true
        }
    }

    func confirmJoin() async -> MoneySnapGroup? {
        guard let pendingJoinCode, joinPreview != nil else { return nil }
        do {
            let joined = try await client.join(
                code: pendingJoinCode,
                mutationID: mutationID().uuidString.lowercased()
            )
            joinPreview = nil
            self.pendingJoinCode = nil
            failed = false
            await load()
            return joined
        } catch {
            failed = true
            return nil
        }
    }

    func cancelJoin() {
        joinPreview = nil
        pendingJoinCode = nil
    }

    func remove(memberID: UUID) async {
        do {
            try await client.removeMember(groupID: group.id, memberID: memberID)
            await load()
        } catch {
            failed = true
        }
    }

    func leave() async -> Bool {
        do {
            try await client.leave(groupID: group.id)
            return true
        } catch {
            failed = true
            return false
        }
    }

    func deleteGroup() async -> Bool {
        do {
            try await client.deleteGroup(
                groupID: group.id,
                mutationID: mutationID().uuidString.lowercased()
            )
            return true
        } catch {
            failed = true
            return false
        }
    }
}
