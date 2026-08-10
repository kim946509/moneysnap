import SwiftUI

@main
struct MoneySnapApp: App {
    @State private var selectedTab = AppTab.initial

    var body: some Scene {
        WindowGroup {
            AppShellView(selectedTab: $selectedTab)
        }
    }
}
