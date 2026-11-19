import SwiftUI

/// Score, grade, stars and (optionally) the three-part breakdown.
struct DealScoreCard: View {
    let rating: DealRating
    var showsBreakdown = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                ScoreRing(score: rating.score, color: rating.grade.color)
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(rating.grade.name)
                        .font(.headline)
                        .foregroundStyle(rating.grade.color)
                    StarsView(count: rating.grade.stars)
                    Text(rating.headline)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if showsBreakdown {
                ScoreBar(label: "Price vs value", points: rating.pricePoints, maximum: DealRater.maxPricePoints, color: rating.grade.color)
                ScoreBar(label: "What you get", points: rating.qualityPoints, maximum: DealRater.maxQualityPoints, color: rating.grade.color)
                ScoreBar(label: "Low risk", points: rating.riskPoints, maximum: DealRater.maxRiskPoints, color: rating.grade.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text("All-in cost \(Fmt.money(rating.allInCost)) vs value \(Fmt.money(rating.estimate.value))")
                    if rating.ratedFactorCount == 0 {
                        Text("Nothing rated yet, so “what you get” counts as average.")
                    }
                    ForEach(rating.riskNotes, id: \.self) { note in
                        Text(note)
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct DealAnalysisView: View {
    @EnvironmentObject private var store: PropertyStore
    let propertyID: UUID
    @State private var draft: DealAnalysis
    @State private var editingSale: ComparableSale?

    init(property: Property) {
        propertyID = property.id
        _draft = State(initialValue: property.analysis)
    }

    var body: some View {
        Group {
            if let saved = store.property(id: propertyID) {
                form(for: preview(of: saved))
            } else {
                Text("This property was deleted.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Deal analysis")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: draft) { newValue in
            store.update(propertyID) { $0.analysis = newValue }
        }
        .sheet(item: $editingSale) { sale in
            ComparableSaleEditor(sale: sale, unit: store.property(id: propertyID)?.kind.sizeUnit ?? .squareFeet) { saved in
                if let index = draft.comparables.firstIndex(where: { $0.id == saved.id }) {
                    draft.comparables[index] = saved
                } else {
                    draft.comparables.append(saved)
                }
            }
        }
    }

    /// The saved property with the edits on screen applied.
    private func preview(of property: Property) -> Property {
        var copy = property
        copy.analysis = draft
        return copy
    }

    private func form(for property: Property) -> some View {
        Form {
            scoreSection(property)
            valueSection(property)
            costsSection
            qualitySection
            riskSection(property)
            MaxOfferSections(
                analysis: $draft,
                inputs: MaxOffer.inputs(for: property),
                askingPrice: property.askingPrice
            )
        }
    }

    private func scoreSection(_ property: Property) -> some View {
        Section {
            if let rating = DealRater.rate(property) {
                DealScoreCard(rating: rating)
                if let inputs = DealRater.inputs(for: property),
                   let goodPrice = DealRater.highestPrice(for: inputs, minimumScore: DealGrade.good.minimumScore) {
                    AmountRow(label: "Pay at most this for a Good deal", amount: goodPrice)
                }
                if let maxPrice = property.maxPrice,
                   property.askingPrice != nil,
                   let atMax = DealRater.rate(property, price: maxPrice) {
                    InfoRow(label: "At your maximum (\(Fmt.money(maxPrice)))", value: "\(atMax.score) · \(atMax.grade.shortName)")
                }
            } else {
                Text(DealRater.missingInfoMessage(for: property))
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Deal score")
        } footer: {
            Text("Out of 100: up to 60 points for the all-in cost (price, land transfer tax, renovation and closing) compared with the estimated value, 25 for what you get, and 15 for low risk. Rated at the asking price. 80+ Excellent, 65+ Good, 50+ Fair, 35+ Below average.")
        }
    }

    private func valueSection(_ property: Property) -> some View {
        let unit = property.kind.sizeUnit
        let estimate = DealRater.estimate(for: draft)
        return Section {
            NumberField(title: "Estimated value", value: $draft.estimatedValue, placeholder: "Optional")
            NumberField(title: "Size", value: $draft.size, placeholder: "0", suffix: unit.label)
            ForEach(draft.comparables) { sale in
                Button {
                    editingSale = sale
                } label: {
                    ComparableRow(sale: sale, unit: unit)
                }
            }
            .onDelete { offsets in
                draft.comparables.remove(atOffsets: offsets)
            }
            Button {
                editingSale = ComparableSale()
            } label: {
                Label("Add a comparable sale", systemImage: "plus.circle")
            }
            if let estimate {
                AmountRow(label: "Value used", amount: estimate.value, emphasized: true)
            }
        } header: {
            Text("Value")
        } footer: {
            Text(estimate?.explanation(unit: unit)
                 ?? "Enter what it would be worth in good condition, or add recent sales of similar properties (from HouseSigma or MPAC) and the app works it out.")
        }
    }

    private var costsSection: some View {
        Section {
            NumberField(title: "Renovation & repairs", value: $draft.renovationCost, placeholder: "0")
            NumberField(title: "Legal & closing", value: $draft.closingCosts, placeholder: "2500")
        } header: {
            Text("Costs")
        } footer: {
            Text("Land transfer tax is added automatically. Legal and closing costs default to $2,500.")
        }
    }

    private var qualitySection: some View {
        Section {
            ForEach(QualityFactor.allCases) { factor in
                StarRatingPicker(title: factor.name, detail: factor.detail, rating: ratingBinding(for: factor))
            }
        } header: {
            Text("What you get")
        } footer: {
            Text("Tap a star to rate and tap it again to clear. Anything not rated counts as average.")
        }
    }

    private func riskSection(_ property: Property) -> some View {
        let typePenalty = Int(DealRater.saleTypePenalty(property.saleType))
        return Section {
            ForEach(RiskFactor.allCases) { risk in
                Toggle(risk.name, isOn: riskBinding(for: risk))
            }
        } header: {
            Text("Risks")
        } footer: {
            Text(typePenalty > 0
                 ? "Each risk takes 3 points off. \(property.saleType.name) properties also lose \(typePenalty) automatically."
                 : "Each risk takes 3 points off.")
        }
    }

    private func ratingBinding(for factor: QualityFactor) -> Binding<Int> {
        Binding(
            get: { draft.rating(for: factor) },
            set: { draft.setRating($0, for: factor) }
        )
    }

    private func riskBinding(for risk: RiskFactor) -> Binding<Bool> {
        Binding(
            get: { draft.hasRisk(risk) },
            set: { draft.setRisk(risk, $0) }
        )
    }
}

struct ComparableRow: View {
    let sale: ComparableSale
    let unit: SizeUnit

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(sale.address.trimmed.isEmpty ? "Comparable sale" : sale.address)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Text(Fmt.money(sale.soldPrice))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    private var detail: String {
        var parts: [String] = []
        if let size = sale.size, size > 0 {
            parts.append("\(size.formatted()) \(unit.label)")
            parts.append("\(Fmt.money(sale.soldPrice / size)) per \(unit.singular)")
        }
        if let date = sale.soldDate {
            parts.append("Sold \(date.formatted(date: .abbreviated, time: .omitted))")
        }
        return parts.isEmpty ? "Add a size to compare price per \(unit.singular)" : parts.joined(separator: " · ")
    }
}

struct ComparableSaleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sale: ComparableSale
    @State private var hasDate: Bool
    let unit: SizeUnit
    let onSave: (ComparableSale) -> Void

    init(sale: ComparableSale, unit: SizeUnit, onSave: @escaping (ComparableSale) -> Void) {
        _sale = State(initialValue: sale)
        _hasDate = State(initialValue: sale.soldDate != nil)
        self.unit = unit
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Address", text: $sale.address)
                        .textInputAutocapitalization(.words)
                    NumberField(title: "Sold price", value: soldPrice, placeholder: "Required")
                    NumberField(title: "Size", value: $sale.size, placeholder: "Optional", suffix: unit.label)
                    Toggle("Sold date", isOn: $hasDate.animation())
                    if hasDate {
                        DatePicker("Date", selection: soldDate, displayedComponents: .date)
                    }
                } footer: {
                    Text("Use sales from the last 6–12 months that are as similar as possible. HouseSigma and MPAC show sold prices.")
                }
            }
            .navigationTitle("Comparable sale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var saved = sale
                        saved.address = saved.address.trimmed
                        if !hasDate { saved.soldDate = nil }
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(sale.soldPrice <= 0)
                }
            }
        }
    }

    private var soldPrice: Binding<Double?> {
        Binding(
            get: { sale.soldPrice > 0 ? sale.soldPrice : nil },
            set: { sale.soldPrice = $0 ?? 0 }
        )
    }

    private var soldDate: Binding<Date> {
        Binding(
            get: { sale.soldDate ?? Date() },
            set: { sale.soldDate = $0 }
        )
    }
}

/// Plan, financing and the resulting maximum offer. Used for saved properties and in Tools.
struct MaxOfferSections: View {
    @Binding var analysis: DealAnalysis
    let inputs: MaxOffer.Inputs?
    let askingPrice: Double?

    var body: some View {
        Section {
            Toggle("I'll resell after renovating", isOn: $analysis.resell)
            Stepper("Holding period: \(analysis.holdingMonths) \(analysis.holdingMonths == 1 ? "month" : "months")",
                    value: $analysis.holdingMonths, in: 1...60)
            NumberField(title: "Target profit", value: $analysis.targetProfitPercent.optional(), suffix: "% of value")
            if analysis.resell {
                NumberField(title: "Selling costs", value: $analysis.sellingCostPercent.optional(), suffix: "%")
            }
        } header: {
            Text("Your plan")
        } footer: {
            Text(analysis.resell
                 ? "Target profit is a share of the estimated value. Selling costs cover commission and legal fees when you resell."
                 : "If you're keeping it, the target is the equity you want on day one, as a share of the estimated value.")
        }

        Section {
            NumberField(title: "Down payment", value: $analysis.downPaymentPercent.optional(), suffix: "%")
            NumberField(title: "Interest rate", value: $analysis.interestRate.optional(), suffix: "%")
            NumberField(title: "Amortization", value: $analysis.amortizationYears.optional(fallback: 25), suffix: "yrs")
            NumberField(title: "Property tax", value: $analysis.propertyTaxYearly, placeholder: "1% of price", suffix: "/yr")
            NumberField(title: "Insurance", value: $analysis.insuranceYearly, placeholder: "2000", suffix: "/yr")
            NumberField(title: "Utilities & upkeep", value: $analysis.utilitiesMonthly, placeholder: "300", suffix: "/mo")
        } header: {
            Text("Financing & carrying costs")
        } footer: {
            Text("Carrying costs are counted for the holding period. Vacant land usually needs 25–50% down.")
        }

        MaxOfferResultSection(inputs: inputs, askingPrice: askingPrice)
    }
}

struct MaxOfferResultSection: View {
    let inputs: MaxOffer.Inputs?
    let askingPrice: Double?

    var body: some View {
        Section {
            if let inputs {
                if let best = MaxOffer.maximumOffer(inputs) {
                    AmountRow(label: "Maximum offer", amount: best.price, emphasized: true)
                    OutcomeRows(outcome: best)
                } else {
                    Text("Even at $0 the costs are too high to hit your target. Lower the target or the renovation budget.")
                        .foregroundStyle(.secondary)
                }
                if let askingPrice, askingPrice > 0 {
                    let atAsking = MaxOffer.outcome(price: askingPrice, inputs: inputs)
                    AmountRow(label: "Profit at the asking price", amount: atAsking.profit)
                    AmountRow(label: "Cash needed at the asking price", amount: atAsking.cashNeeded)
                }
            } else {
                Text("Add an estimated value or comparable sales to work out a maximum offer.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Maximum offer")
        } footer: {
            Text("Works backwards from the estimated value, minus renovation, land transfer tax, closing, interest, taxes, insurance, utilities, any selling costs and your target. Estimate only.")
        }
    }
}

struct OutcomeRows: View {
    let outcome: MaxOffer.Outcome

    var body: some View {
        AmountRow(label: "Land transfer tax", amount: outcome.landTransferTax)
        AmountRow(label: "Legal & closing", amount: outcome.closing)
        AmountRow(label: "Renovation", amount: outcome.renovation)
        AmountRow(label: "Mortgage interest", amount: outcome.interest)
        AmountRow(label: "Taxes, insurance & utilities", amount: outcome.propertyTax + outcome.insurance + outcome.utilities)
        if outcome.sellingCosts > 0 {
            AmountRow(label: "Selling costs", amount: outcome.sellingCosts)
        }
        AmountRow(label: "Profit or equity", amount: outcome.profit)
        AmountRow(label: "Cash needed", amount: outcome.cashNeeded)
    }
}
