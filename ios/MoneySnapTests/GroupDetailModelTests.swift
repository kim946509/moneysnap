import Foundation
import Testing
@testable import MoneySnap

@MainActor
struct GroupDetailModelTests {
    @Test
    func previewDoesNotJoinUntilConfirmed() async {
        let client = RecordingGroupClient()
        client.previewResult = InvitePreview(name: "주말 모임", amountVisible: false)
        let model = GroupDetailModel(group: .owned, client: client)

        await model.previewInvite(code: "invite-code")

        #expect(model.joinPreview == InvitePreview(name: "주말 모임", amountVisible: false))
        #expect(client.joinCalls.isEmpty)
    }

    @Test
    func confirmJoinUsesThePreviewedCodeOnce() async {
        let client = RecordingGroupClient()
        client.previewResult = InvitePreview(name: "주말 모임", amountVisible: true)
        client.joinResult = .owned
        let model = GroupDetailModel(
            group: .owned,
            client: client,
            mutationID: { UUID(uuidString: "11111111-1111-4111-8111-111111111111")! }
        )

        await model.previewInvite(code: "invite-code")
        let joined = await model.confirmJoin()

        #expect(joined?.name == "주말 모임")
        #expect(client.joinCalls == [
            JoinCall(code: "invite-code", mutationID: "11111111-1111-4111-8111-111111111111")
        ])
        #expect(model.joinPreview == nil)
    }

    @Test
    func ownerCanRemoveAMemberAndReload() async {
        let client = RecordingGroupClient()
        let memberID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        client.membersResult = GroupMemberList(members: [
            GroupMember(userId: memberID, displayName: "친구", avatar: "친", role: "member")
        ])
        let model = GroupDetailModel(group: .owned, client: client)
        await model.load()

        await model.remove(memberID: memberID)

        #expect(client.removedMemberIDs == [memberID])
        #expect(client.membersCalls == 2)
    }

    @Test
    func canvasOrderFollowsSavedIdsThenCreatedAt() {
        UserDefaults.standard.removeObject(forKey: "moneysnap.group-canvas-order")
        let older = MoneySnapGroup(
            id: UUID(uuidString: "018f1e2d-aaaa-7abc-8def-0123456789ab")!,
            name: "먼저",
            amountVisible: true,
            role: .owner,
            createdAt: Date(timeIntervalSince1970: 1)
        )
        let newer = MoneySnapGroup(
            id: UUID(uuidString: "018f1e2d-bbbb-7abc-8def-0123456789ab")!,
            name: "나중",
            amountVisible: false,
            role: .member,
            createdAt: Date(timeIntervalSince1970: 2)
        )

        #expect(GroupCanvasOrder.apply([newer, older]).map(\.id) == [older.id, newer.id])

        GroupCanvasOrder.save([newer, older])
        #expect(GroupCanvasOrder.apply([older, newer]).map(\.id) == [newer.id, older.id])
        UserDefaults.standard.removeObject(forKey: "moneysnap.group-canvas-order")
    }

    @Test
    func ownerCanDeleteTheGroup() async {
        let client = RecordingGroupClient()
        let model = GroupDetailModel(
            group: .owned,
            client: client,
            mutationID: { UUID(uuidString: "11111111-1111-4111-8111-111111111111")! }
        )

        #expect(await model.deleteGroup())
        #expect(client.deletedGroupIDs == [MoneySnapGroup.owned.id])
    }
}

@MainActor
private final class RecordingGroupClient: GroupClient {
    var previewResult: InvitePreview?
    var joinResult: MoneySnapGroup = .owned
    var membersResult = GroupMemberList(members: [])
    var joinCalls: [JoinCall] = []
    var removedMemberIDs: [UUID] = []
    var deletedGroupIDs: [UUID] = []
    var membersCalls = 0

    func list() async throws -> GroupList { GroupList(groups: []) }
    func create(_ command: GroupCreateCommand) async throws -> MoneySnapGroup { .owned }

    func visibleToday(groupID: UUID) async throws -> VisibleGroupToday {
        _ = groupID
        return VisibleGroupToday(localDay: "2026-08-13", members: [])
    }

    func hiddenToday(groupID: UUID) async throws -> HiddenGroupToday {
        _ = groupID
        return HiddenGroupToday(localDay: "2026-08-13", members: [])
    }

    func preview(code: String) async throws -> InvitePreview {
        _ = code
        guard let previewResult else {
            throw SnapJournalClientError.unavailable
        }
        return previewResult
    }

    func join(code: String, mutationID: String) async throws -> MoneySnapGroup {
        joinCalls.append(JoinCall(code: code, mutationID: mutationID))
        return joinResult
    }

    func members(groupID: UUID) async throws -> GroupMemberList {
        _ = groupID
        membersCalls += 1
        return membersResult
    }

    func removeMember(groupID: UUID, memberID: UUID) async throws {
        _ = groupID
        removedMemberIDs.append(memberID)
        membersResult = GroupMemberList(members: [])
    }

    func deleteGroup(groupID: UUID, mutationID: String) async throws {
        _ = mutationID
        deletedGroupIDs.append(groupID)
    }
}

private struct JoinCall: Equatable {
    let code: String
    let mutationID: String
}

private extension MoneySnapGroup {
    static let owned = MoneySnapGroup(
        id: UUID(uuidString: "018f1e2d-aaaa-7abc-8def-0123456789ab")!,
        name: "주말 모임",
        amountVisible: true,
        role: .owner,
        createdAt: Date(timeIntervalSince1970: 1_786_582_800)
    )
}
