public enum AppTab: String, CaseIterable, Identifiable, Hashable, Sendable {
    case home
    case group
    case add
    case archive
    case profile

    public static let initial: AppTab = .home

    public var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "홈"
        case .group: "그룹"
        case .add: "추가"
        case .archive: "보관함"
        case .profile: "마이"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .group: "person"
        case .add: "plus"
        case .archive: "folder"
        case .profile: "person.crop.circle"
        }
    }
}
