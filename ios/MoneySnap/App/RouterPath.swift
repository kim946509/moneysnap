import Foundation
import Observation
import SwiftUI

public enum AppRoute: Hashable {
    case snapDetail(id: UUID)
}

@MainActor
@Observable
public final class RouterPath {
    public var path: [AppRoute] = []

    public init() {}

    public func navigate(to route: AppRoute) {
        path.append(route)
    }

    public func reset() {
        path.removeAll()
    }
}

@MainActor
@Observable
public final class TabRouter {
    private var routers: [AppTab: RouterPath]

    public init() {
        routers = Dictionary(
            uniqueKeysWithValues: AppTab.allCases.map { ($0, RouterPath()) }
        )
    }

    public func router(for tab: AppTab) -> RouterPath {
        guard let router = routers[tab] else {
            preconditionFailure("Missing router for tab: \(tab)")
        }
        return router
    }

    func binding(for tab: AppTab) -> Binding<[AppRoute]> {
        let router = router(for: tab)
        return Binding(
            get: { router.path },
            set: { router.path = $0 }
        )
    }
}
