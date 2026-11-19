import SwiftUI

struct ToolsView: View {
    @AppStorage(SettingsKeys.openLinksInSafari) private var openLinksInSafari = false

    var body: some View {
        NavigationStack {
            List {
                Section("Calculators") {
                    NavigationLink {
                        LandTransferTaxView()
                    } label: {
                        Label("Land transfer tax & cash to close", systemImage: "percent")
                    }
                    NavigationLink {
                        TaxSaleTenderView()
                    } label: {
                        Label("Tax sale tender", systemImage: "doc.text")
                    }
                }
                Section("Reference") {
                    NavigationLink {
                        KeywordsView()
                    } label: {
                        Label("Search keywords", systemImage: "textformat.abc")
                    }
                }
                Section {
                    Toggle("Open links in the Safari app", isOn: $openLinksInSafari)
                } header: {
                    Text("Settings")
                } footer: {
                    Text("When this is off, web pages open inside the app.")
                }
                Section {
                    InfoRow(label: "Version", value: Bundle.main.appVersion)
                    Text("Listings come from public websites. This app doesn't copy or store listing data; it opens the sites and searches for you.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("If you installed with a free Apple ID, the app needs to be refreshed every 7 days. Export a backup from the Watchlist menu now and then.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Tools")
        }
    }
}

struct LandTransferTaxView: View {
    @State private var priceText = ""
    @State private var isHome = true
    @State private var inToronto = false
    @State private var firstTimeBuyer = false
    @State private var downPaymentPercent = 20.0
    @State private var legalText = "2500"
    @State private var otherText = "1000"

    private var price: Double { MoneyParser.parse(priceText) ?? 0 }
    private var legal: Double { MoneyParser.parse(legalText) ?? 0 }
    private var other: Double { MoneyParser.parse(otherText) ?? 0 }

    private var estimate: LandTransferTax.Estimate {
        LandTransferTax.estimate(price: price, isHome: isHome, inToronto: inToronto, firstTimeBuyer: firstTimeBuyer)
    }

    private var downPayment: Double {
        price * downPaymentPercent / 100
    }

    var body: some View {
        Form {
            Section {
                TextField("Purchase price", text: $priceText)
                    .keyboardType(.numbersAndPunctuation)
                Toggle("Home with 1–2 single-family residences", isOn: $isHome)
                Toggle("In the City of Toronto", isOn: $inToronto)
                Toggle("First-time home buyer", isOn: $firstTimeBuyer)
                    .disabled(!isHome)
            } header: {
                Text("Purchase")
            } footer: {
                Text("Turn off “Home” for vacant land, commercial property or more than two homes.")
            }

            Section("Land transfer tax") {
                AmountRow(label: "Ontario", amount: estimate.ontario)
                if estimate.ontarioRefund > 0 {
                    AmountRow(label: "First-time buyer refund", amount: -estimate.ontarioRefund)
                }
                if inToronto {
                    AmountRow(label: "Toronto", amount: estimate.toronto)
                    if estimate.torontoRebate > 0 {
                        AmountRow(label: "Toronto first-time rebate", amount: -estimate.torontoRebate)
                    }
                }
                AmountRow(label: "Total land transfer tax", amount: estimate.total, emphasized: true)
            }

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Down payment: \(Int(downPaymentPercent))%")
                    Slider(value: $downPaymentPercent, in: 5...100, step: 5)
                }
                HStack {
                    Text("Legal fees")
                    TextField("Legal fees", text: $legalText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                HStack {
                    Text("Inspection, title insurance, other")
                    TextField("Other", text: $otherText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
                AmountRow(label: "Down payment", amount: downPayment)
                AmountRow(label: "Land transfer tax", amount: estimate.total)
                AmountRow(label: "Legal and other", amount: legal + other)
                AmountRow(label: "Cash needed to close", amount: downPayment + estimate.total + legal + other, emphasized: true)
                AmountRow(label: "Mortgage needed", amount: max(price - downPayment, 0))
            } header: {
                Text("Cash to close")
            } footer: {
                Text("Vacant land usually needs 25–50% down. Homes under 20% down need mortgage insurance, which isn't included here.")
            }

            Section {
                Text("Estimate only. Rates were current when this app was built and can change. HST, adjustments and mortgage insurance aren't included. Confirm with your lawyer.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Land transfer tax")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: isHome) { newValue in
            if !newValue { firstTimeBuyer = false }
        }
    }
}

struct TaxSaleTenderView: View {
    @State private var minimumText = ""
    @State private var tenderText = ""
    @State private var isHome = false
    @State private var hstApplies = false
    @State private var legalText = "2000"

    private var minimum: Double? { MoneyParser.parse(minimumText) }
    private var tender: Double { MoneyParser.parse(tenderText) ?? 0 }
    private var legal: Double { MoneyParser.parse(legalText) ?? 0 }

    private var breakdown: TaxSaleTender.Breakdown {
        TaxSaleTender.breakdown(tender: tender, minimum: minimum, isHome: isHome, hstApplies: hstApplies)
    }

    var body: some View {
        Form {
            Section {
                TextField("Minimum tender amount", text: $minimumText)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Your tender", text: $tenderText)
                    .keyboardType(.numbersAndPunctuation)
                Toggle("Has a house (1–2 single-family homes)", isOn: $isHome)
                Toggle("HST applies", isOn: $hstApplies)
                HStack {
                    Text("Legal fees")
                    TextField("Legal fees", text: $legalText)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Tender")
            } footer: {
                Text("The minimum tender amount (the cancellation price) is in the municipality's advertisement and tender package.")
            }

            if breakdown.isBelowMinimum {
                Section {
                    Callout(
                        text: "Your tender is below the minimum tender amount, so it would be rejected.",
                        symbol: "exclamationmark.triangle",
                        color: .red
                    )
                    .listRowInsets(EdgeInsets())
                }
            }

            Section {
                AmountRow(label: "Deposit with your tender (20%)", amount: breakdown.deposit, emphasized: true)
            } header: {
                Text("With your tender")
            } footer: {
                Text("By certified cheque, bank draft or money order, made out to the municipality.")
            }

            Section {
                AmountRow(label: "Balance of tender", amount: breakdown.balance)
                AmountRow(label: "Land transfer tax", amount: breakdown.landTransferTax)
                if hstApplies {
                    AmountRow(label: "HST (13%)", amount: breakdown.hst)
                }
                AmountRow(label: "Legal fees", amount: legal)
                AmountRow(label: "Due after you win", amount: breakdown.balance + breakdown.landTransferTax + breakdown.hst + legal, emphasized: true)
            } header: {
                Text("If you win")
            } footer: {
                Text("Usually due within 14 days, plus any taxes that built up since the sale was advertised. The municipality tells you the exact amount.")
            }

            Section {
                AmountRow(label: "Total cost", amount: breakdown.totalDue + legal, emphasized: true)
            }
        }
        .navigationTitle("Tax sale tender")
        .navigationBarTitleDisplayMode(.inline)
    }
}
