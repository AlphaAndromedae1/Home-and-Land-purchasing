import SwiftUI
import UIKit
import WebKit

/// Drives the in-app browser's web view and reads the current page when the user taps Save.
@MainActor
final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    @Published private(set) var title = ""
    @Published private(set) var currentURL: URL?
    @Published private(set) var canGoBack = false
    @Published private(set) var canGoForward = false
    @Published private(set) var isLoading = false
    @Published private(set) var progress = 0.0

    let webView: WKWebView
    private var observations: [NSKeyValueObservation] = []
    private var hasLoaded = false

    override init() {
        let configuration = WKWebViewConfiguration()
        // Identify as mobile Safari so sites show their normal mobile pages.
        configuration.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/604.1"
        configuration.allowsInlineMediaPlayback = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        observations = [
            webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in self?.title = webView.title ?? "" }
            },
            webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in self?.currentURL = webView.url }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in self?.canGoBack = webView.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in self?.canGoForward = webView.canGoForward }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in self?.isLoading = webView.isLoading }
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in self?.progress = webView.estimatedProgress }
            },
        ]
    }

    var host: String {
        var host = currentURL?.host ?? ""
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        return host
    }

    func load(_ url: URL) {
        guard !hasLoaded else { return }
        hasLoaded = true
        webView.load(URLRequest(url: url))
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() { webView.reload() }

    /// Reads the title, metadata, structured data and text of the page on screen.
    func clipPage() async -> ClippedPage? {
        guard let url = webView.url else { return nil }
        let fallback = ClippedPage(url: url, title: webView.title ?? "")
        // The script always returns a string, so the result is never nil.
        let value = try? await webView.evaluateJavaScript(PageClipper.script)
        guard let json = value as? String, let data = json.data(using: .utf8) else { return fallback }
        return PageClipper.page(fromJSON: data, fallbackURL: url)
    }

    // Links that open a new window load in this one instead.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    // Phone, email and app links can't load in a web view, so hand them to iOS.
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        let nsError = error as NSError
        guard let url = nsError.userInfo[NSURLErrorFailingURLErrorKey] as? URL,
              let scheme = url.scheme?.lowercased(),
              scheme != "http", scheme != "https"
        else { return }
        UIApplication.shared.open(url)
    }
}

struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// The in-app browser. Its Save button adds the listing on screen to the watchlist.
struct InAppBrowser: View {
    let url: URL

    @EnvironmentObject private var store: PropertyStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = BrowserModel()
    @State private var draft: Property?
    @State private var isSaving = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            WebViewContainer(webView: model.webView)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .top) {
                    if model.isLoading {
                        ProgressView(value: model.progress)
                            .progressViewStyle(.linear)
                    }
                }
                .navigationTitle(model.host.isEmpty ? (url.host ?? "") : model.host)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarContent }
        }
        .onAppear {
            model.load(url)
        }
        .sheet(item: $draft) { property in
            PropertyEditorView(property: property)
                .environmentObject(store)
        }
        .alert("Save listing", isPresented: messageIsShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await saveListing() }
            } label: {
                if isSaving {
                    ProgressView()
                } else {
                    Label("Save", systemImage: "star")
                        .labelStyle(.titleAndIcon)
                }
            }
            .disabled(isSaving)
        }
        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                model.goBack()
            } label: {
                Image(systemName: "chevron.backward")
            }
            .disabled(!model.canGoBack)
            .accessibilityLabel("Back")
            Spacer()
            Button {
                model.goForward()
            } label: {
                Image(systemName: "chevron.forward")
            }
            .disabled(!model.canGoForward)
            .accessibilityLabel("Forward")
            Spacer()
            Button {
                model.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .accessibilityLabel("Reload")
            Spacer()
            ShareLink(item: model.currentURL ?? url) {
                Image(systemName: "square.and.arrow.up")
            }
            Spacer()
            Button {
                UIApplication.shared.open(model.currentURL ?? url)
            } label: {
                Image(systemName: "safari")
            }
            .accessibilityLabel("Open in Safari")
        }
    }

    private var messageIsShown: Binding<Bool> {
        Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )
    }

    /// Opens the add-property form, pre-filled from the page on screen.
    private func saveListing() async {
        guard !isSaving else { return }
        isSaving = true
        defer { isSaving = false }
        guard let page = await model.clipPage() else {
            message = "Wait for the page to finish loading, then tap Save again."
            return
        }
        if let existing = store.properties.first(where: { $0.listingURL == page.url.absoluteString }) {
            draft = existing
        } else {
            draft = PageClipper.property(from: page)
        }
    }
}
