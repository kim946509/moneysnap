public enum AppTab: String, CaseIterable, Identifiable, Hashable {
    case home
    case group
    case add
    case archive
    case profile

    public static let initial: AppTab = .home

    public var id: String { rawValue }
}
