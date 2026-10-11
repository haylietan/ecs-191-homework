import SwiftUI

@main
struct SetlogApp: App {
    @State private var store = SetlogStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.light)
                .tint(Theme.roseDeep)
        }
    }
}
