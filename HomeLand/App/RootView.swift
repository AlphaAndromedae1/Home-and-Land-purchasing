import SwiftUI

/// A URL wrapped so it can drive `.sheet(item:)`.
struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

enum SettingsKeys {
    static let openLinksInSafari = "settings.openLinksInSafari"
    static let remindersEnabled = "settings.remindersEnabled"
}

struct RootView: View {
    enum AppTab: Hashable {
        case find, watchlist, guide, tools
    }

    @EnvironmentObject private var store: PropertyStore
    @AppStorage(SettingsKeys.openLinksInSafari) private var openLinksInSafari = false
    @AppStorage(SettingsKeys.remindersEnabled) private var remindersEnabled = true
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
            InAppBrowser(url: page.url)
                .environmentObject(store)
        }
        // Keep deadline notifications in step with the watchlist.
        .onReceive(store.$properties) { properties in
            ReminderScheduler.shared.sync(properties, enabled: remindersEnabled)
        }
        .onChange(of: remindersEnabled) { enabled in
            ReminderScheduler.shared.sync(store.properties, enabled: enabled)
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
