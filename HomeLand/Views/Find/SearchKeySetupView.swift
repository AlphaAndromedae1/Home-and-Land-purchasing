import SwiftUI

/// Where the user adds the Brave Search API key that turns on in-app listings.
struct SearchKeySetupView: View {
    @EnvironmentObject private var searchKeys: SearchKeyStore
    @Environment(\.openURL) private var openURL

    @State private var keyText = ""
    @State private var status: String?
    @State private var isTesting = false
    @State private var usage = ListingSearchUsage.count()

    private static let dashboard = URL(string: "https://api-dashboard.search.brave.com/")!

    var body: some View {
        Form {
            Section {
                Text("Realtor.ca and other listing sites don't offer a public data feed. With a Brave Search API key, the app searches Brave's index of public listing pages and shows the results here as listings with prices, photos and details. Save any of them to your watchlist with one tap.")
            }

            Section {
                Text("1. Open the Brave Search API dashboard and create an account.")
                Text("2. Subscribe to the **Search** plan.")
                Text("3. Under API Keys, create a key and copy it.")
                Text("4. Paste it below and tap Save.")
                Button {
                    openURL(Self.dashboard)
                } label: {
                    Label("Open the Brave Search API dashboard", systemImage: "arrow.up.forward.square")
                }
            } header: {
                Text("Get a key")
            } footer: {
                Text("Brave includes $5 of free credit each month, roughly 1,000 searches, and charges about $5 per 1,000 after that. They may ask for a card. Check current pricing on Brave's site.")
            }

            Section {
                if let key = searchKeys.apiKey {
                    InfoRow(label: "Saved key", value: masked(key))
                    Button {
                        Task { await testKey() }
                    } label: {
                        if isTesting {
                            ProgressView()
                        } else {
                            Label("Test the key", systemImage: "checkmark.seal")
                        }
                    }
                    .disabled(isTesting)
                    Button("Remove key", role: .destructive) {
                        searchKeys.remove()
                        status = nil
                    }
                } else {
                    SecureField("Paste your API key", text: $keyText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    PasteButton(payloadType: String.self) { strings in
                        Task { @MainActor in
                            keyText = strings.first?.trimmed ?? ""
                        }
                    }
                    Button("Save key") {
                        if searchKeys.save(keyText) {
                            keyText = ""
                            status = "Key saved. Run a search from the Find tab."
                        } else {
                            status = "Couldn't save the key. Try again."
                        }
                    }
                    .disabled(keyText.trimmed.isEmpty)
                }
                if let status {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Your key")
            } footer: {
                Text("Stored in your iPhone's Keychain and only sent to Brave when you search.")
            }

            Section {
                InfoRow(label: "Searches this month", value: "\(usage)")
            } footer: {
                Text("Each page of up to 20 results is one search. Repeating a search within 30 minutes uses the saved results and doesn't count.")
            }
        }
        .navigationTitle("Listing search")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            usage = ListingSearchUsage.count()
        }
    }

    private func masked(_ key: String) -> String {
        key.count <= 8 ? "••••••••" : "\(key.prefix(4))••••\(key.suffix(4))"
    }

    private func testKey() async {
        guard let key = searchKeys.apiKey else { return }
        isTesting = true
        defer { isTesting = false }
        do {
            let page = try await BraveSearchClient(apiKey: key).search(query: "site:realtor.ca Ontario", freshness: nil, page: 0)
            ListingSearchUsage.record()
            usage = ListingSearchUsage.count()
            status = "The key works. Brave returned \(page.results.count) results."
        } catch {
            status = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
