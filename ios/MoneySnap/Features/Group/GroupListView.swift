import SwiftUI

struct GroupListView: View {
    let client: any GroupClient
    @State private var groups: [MoneySnapGroup] = []
    @State private var failed = false
    @State private var presentsCreate = false
    @State private var presentsJoin = false
    @State private var draftName = ""
    @State private var amountVisible = true
    @State private var joinCode = ""
    @State private var joinPreview: InvitePreview?

    var body: some View {
        Group {
            if failed && groups.isEmpty {
                ContentUnavailableView {
                    Label("그룹을 불러오지 못했어요", systemImage: "exclamationmark.triangle")
                        .accessibilityIdentifier("screen.group")
                } actions: {
                    Button("다시 시도") { Task { await load() } }
                        .frame(minWidth: 44, minHeight: 44)
                }
            } else if groups.isEmpty {
                ContentUnavailableView {
                    Label("아직 그룹이 없어요", systemImage: "person.2")
                        .accessibilityIdentifier("screen.group")
                } actions: {
                    Button("그룹 만들기") { presentsCreate = true }
                        .frame(minWidth: 44, minHeight: 44)
                        .accessibilityIdentifier("group.create")
                }
            } else {
                List {
                    ForEach(groups) { group in
                        NavigationLink {
                            GroupDetailView(group: group, client: client) {
                                Task { await load() }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(group.name)
                                    .font(.moneySnap(size: 17, weight: .bold))
                                Text(group.amountVisible ? "금액 공개" : "금액 비공개")
                                    .font(.moneySnap(size: 13, weight: .medium))
                                    .foregroundStyle(MoneySnapVisualSystem.secondaryText)
                            }
                            .frame(minHeight: 44)
                        }
                    }
                    .onMove(perform: moveGroups)
                }
                .accessibilityIdentifier("screen.group")
            }
        }
        .task { await load() }
        .toolbar {
            EditButton()
            Button("가입") { presentsJoin = true }
                .frame(minWidth: 44, minHeight: 44)
            Button("만들기") { presentsCreate = true }
                .frame(minWidth: 44, minHeight: 44)
        }
        .sheet(isPresented: $presentsCreate) {
            NavigationStack {
                Form {
                    TextField("그룹 이름", text: $draftName)
                    Toggle("금액 공개", isOn: $amountVisible)
                    Text("금액 공개 여부는 만든 뒤에 바꿀 수 없어요.")
                        .font(.moneySnap(size: 13, weight: .medium))
                }
                .navigationTitle("그룹 만들기")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") { presentsCreate = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("만들기") {
                            Task { await create() }
                        }
                        .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .sheet(isPresented: $presentsJoin) {
            NavigationStack {
                Form {
                    TextField("초대 코드", text: $joinCode)
                    Button("미리보기") {
                        Task { joinPreview = try? await client.preview(code: joinCode) }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                    if let joinPreview {
                        Text(joinPreview.name)
                        Text(joinPreview.amountVisible ? "금액 공개 그룹" : "금액 비공개 그룹")
                        Button("이 그룹 가입") {
                            Task { await join() }
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .navigationTitle("초대 코드로 가입")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { presentsJoin = false }
                    }
                }
            }
        }
    }

    private func load() async {
        do {
            groups = GroupCanvasOrder.apply(try await client.list().groups)
            failed = false
        } catch {
            failed = true
        }
    }

    private func moveGroups(from source: IndexSet, to destination: Int) {
        groups.move(fromOffsets: source, toOffset: destination)
        GroupCanvasOrder.save(groups)
    }

    private func create() async {
        do {
            let created = try await client.create(GroupCreateCommand(
                clientMutationId: UUID().uuidString.lowercased(),
                name: draftName,
                amountVisible: amountVisible
            ))
            if !groups.contains(where: { $0.id == created.id }) {
                groups.insert(created, at: 0)
            }
            draftName = ""
            presentsCreate = false
        } catch {
            failed = true
        }
    }

    private func join() async {
        do {
            let joined = try await client.join(
                code: joinCode,
                mutationID: UUID().uuidString.lowercased()
            )
            if !groups.contains(where: { $0.id == joined.id }) {
                groups.insert(joined, at: 0)
            }
            joinCode = ""
            joinPreview = nil
            presentsJoin = false
            failed = false
        } catch {
            failed = true
        }
    }
}

enum GroupCanvasOrder {
    private static let key = "moneysnap.group-canvas-order"

    static func apply(_ groups: [MoneySnapGroup]) -> [MoneySnapGroup] {
        let saved = (UserDefaults.standard.stringArray(forKey: key) ?? []).compactMap { UUID(uuidString: $0) }
        return groups.sorted { lhs, rhs in
            let left = saved.firstIndex(of: lhs.id) ?? Int.max
            let right = saved.firstIndex(of: rhs.id) ?? Int.max
            if left != right { return left < right }
            return lhs.createdAt < rhs.createdAt
        }
    }

    static func save(_ groups: [MoneySnapGroup]) {
        UserDefaults.standard.set(groups.map { $0.id.uuidString.lowercased() }, forKey: key)
    }
}

protocol GroupClient: Sendable {
    func list() async throws -> GroupList
    func create(_ command: GroupCreateCommand) async throws -> MoneySnapGroup
    func issueInvite(groupID: UUID) async throws -> IssuedInvite
    func members(groupID: UUID) async throws -> GroupMemberList
    func leave(groupID: UUID) async throws
    func preview(code: String) async throws -> InvitePreview
    func join(code: String, mutationID: String) async throws -> MoneySnapGroup
    func visibleToday(groupID: UUID) async throws -> VisibleGroupToday
    func hiddenToday(groupID: UUID) async throws -> HiddenGroupToday
    func share(snapID: UUID, groupID: UUID, mutationID: String) async throws
    func removeMember(groupID: UUID, memberID: UUID) async throws
    func deleteGroup(groupID: UUID, mutationID: String) async throws
    func revokeInvite(groupID: UUID) async throws
}

extension GroupClient {
    func issueInvite(groupID: UUID) async throws -> IssuedInvite {
        throw SnapJournalClientError.unavailable
    }
    func members(groupID: UUID) async throws -> GroupMemberList {
        throw SnapJournalClientError.unavailable
    }
    func leave(groupID: UUID) async throws {
        throw SnapJournalClientError.unavailable
    }
    func preview(code: String) async throws -> InvitePreview {
        throw SnapJournalClientError.unavailable
    }
    func join(code: String, mutationID: String) async throws -> MoneySnapGroup {
        throw SnapJournalClientError.unavailable
    }
    func visibleToday(groupID: UUID) async throws -> VisibleGroupToday {
        throw SnapJournalClientError.unavailable
    }
    func hiddenToday(groupID: UUID) async throws -> HiddenGroupToday {
        throw SnapJournalClientError.unavailable
    }
    func share(snapID: UUID, groupID: UUID, mutationID: String) async throws {
        throw SnapJournalClientError.unavailable
    }
    func removeMember(groupID: UUID, memberID: UUID) async throws {
        throw SnapJournalClientError.unavailable
    }
    func deleteGroup(groupID: UUID, mutationID: String) async throws {
        throw SnapJournalClientError.unavailable
    }
    func revokeInvite(groupID: UUID) async throws {
        throw SnapJournalClientError.unavailable
    }
}

struct UnavailableGroupClient: GroupClient {
    func list() async throws -> GroupList { GroupList(groups: []) }
    func create(_ command: GroupCreateCommand) async throws -> MoneySnapGroup {
        throw SnapJournalClientError.unavailable
    }
}

actor URLSessionGroupClient: GroupClient {
    private let baseURL: URL
    private let session: URLSession
    private let accessToken: @Sendable () async throws -> String

    init(
        baseURL: URL,
        session: URLSession = .shared,
        accessToken: @escaping @Sendable () async throws -> String
    ) {
        self.baseURL = baseURL
        self.session = session
        self.accessToken = accessToken
    }

    func list() async throws -> GroupList {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/groups"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
            throw SnapRecordError.transportFailure
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GroupList.self, from: data)
    }

    func create(_ command: GroupCreateCommand) async throws -> MoneySnapGroup {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/groups"))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(command)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 201 else {
            throw SnapRecordError.transportFailure
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(MoneySnapGroup.self, from: data)
    }

    func issueInvite(groupID: UUID) async throws -> IssuedInvite {
        try await get("/api/v1/groups/\(groupID.uuidString.lowercased())/invites", method: "POST")
    }

    func members(groupID: UUID) async throws -> GroupMemberList {
        try await get("/api/v1/groups/\(groupID.uuidString.lowercased())/members", method: "GET")
    }

    func leave(groupID: UUID) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/groups/\(groupID.uuidString.lowercased())/members/me"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        _ = try await session.data(for: request)
    }

    func preview(code: String) async throws -> InvitePreview {
        try await post("/api/v1/invites/preview", body: ["code": code])
    }

    func join(code: String, mutationID: String) async throws -> MoneySnapGroup {
        try await post("/api/v1/invites/join", body: ["code": code, "clientMutationId": mutationID])
    }

    func visibleToday(groupID: UUID) async throws -> VisibleGroupToday {
        try await get("/api/v1/groups/\(groupID.uuidString.lowercased())/today?timeZone=Asia/Seoul", method: "GET")
    }

    func hiddenToday(groupID: UUID) async throws -> HiddenGroupToday {
        try await get("/api/v1/groups/\(groupID.uuidString.lowercased())/today?timeZone=Asia/Seoul", method: "GET")
    }

    func removeMember(groupID: UUID, memberID: UUID) async throws {
        var request = URLRequest(
            url: baseURL.appending(
                path: "/api/v1/groups/\(groupID.uuidString.lowercased())/members/\(memberID.uuidString.lowercased())"
            )
        )
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 204 else {
            throw SnapRecordError.transportFailure
        }
    }

    func deleteGroup(groupID: UUID, mutationID: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/groups/\(groupID.uuidString.lowercased())"))
        request.httpMethod = "DELETE"
        request.setValue(mutationID, forHTTPHeaderField: "X-Client-Mutation-Id")
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 204 else {
            throw SnapRecordError.transportFailure
        }
    }

    func revokeInvite(groupID: UUID) async throws {
        var request = URLRequest(
            url: baseURL.appending(path: "/api/v1/groups/\(groupID.uuidString.lowercased())/invites")
        )
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 204 else {
            throw SnapRecordError.transportFailure
        }
    }

    func share(snapID: UUID, groupID: UUID, mutationID: String) async throws {
        var request = URLRequest(url: baseURL.appending(path: "/api/v1/shares"))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode([
            "clientMutationId": mutationID,
            "snapId": snapID.uuidString.lowercased(),
            "groupId": groupID.uuidString.lowercased()
        ])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        _ = try await session.data(for: request)
    }

    private func get<T: Decodable>(_ path: String, method: String) async throws -> T {
        let url = path.contains("?")
            ? (URL(string: path, relativeTo: baseURL) ?? baseURL.appending(path: path))
            : baseURL.appending(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: String]) async throws -> T {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(try await accessToken())", forHTTPHeaderField: "Authorization")
        let (data, _) = try await session.data(for: request)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }
}
