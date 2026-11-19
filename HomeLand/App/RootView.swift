import SwiftUI

/// A URL wrapped so it can drive `.sheet(item:)`.
struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

enum SettingsKeys {
    static let openLinksInSafari = "settings.openLinksInSafari"
}

struct RootView: View {
    enum AppTab: Hashable {
        case find, watchlist, guide, tools
    }

    @AppStorage(SettingsKeys.openLinksInSafari) private var openLinksInSafari = false
    @State private var selectedTab: AppTab = .find
    @State private var browserPage: IdentifiedURL?

    var body: some View {
        TabView(selection: $selectedTab) {
            FindView()
                .tabItem { Label("Find", systemImage: "magnifyingglass") }
                .tag(AppTab.find)
            WatchlistView()
                .tabItem { Label("Watchlist", systemImage: "star") }
                .tag(AppTab.watchlist)
            GuideView()
                .tabItem { Label("Guide", systemImage: "book") }
                .tag(AppTab.guide)
            ToolsView()
                .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
                .tag(AppTab.tools)
        }
        // Every link in the app comes through here, so web pages open in an
        // in-app browser unless the user chose the Safari app in Tools.
        .environment(\.openURL, OpenURLAction { url in
            handle(url)
        })
        .sheet(item: $browserPage) { page in
            SafariView(url: page.url)
                .ignoresSafeArea()
        }
    }

    private func handle(_ url: URL) -> OpenURLAction.Result {
        guard !openLinksInSafari, SafariView.canOpen(url) else {
            return .systemAction
        }
        browserPage = IdentifiedURL(url: url)
        return .handled
    }
}
