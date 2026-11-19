import SwiftUI

@main
struct HomeLandApp: App {
    @StateObject private var store = PropertyStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
