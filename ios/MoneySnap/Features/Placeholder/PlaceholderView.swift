import SwiftUI

struct PlaceholderView: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage)
            .navigationTitle(title)
    }
}

#Preview {
    PlaceholderView(title: "홈", systemImage: "house")
}
