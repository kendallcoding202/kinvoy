import StoreKit
import SwiftUI

/// Kinvoy Premium paywall.
///
/// App Review Guideline 3.1.2 requires the price, the billing period, and
/// what's included to be visible before purchase, plus Restore Purchases and
/// links to the Terms of Use and Privacy Policy. All of that lives here.
struct PaywallView: View {
    @EnvironmentObject private var subscriptions: SubscriptionService
    @EnvironmentObject private var familyStore: FamilyStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedID = SubscriptionService.yearlyID

    private var groupName: String { familyStore.family?.name ?? "your group" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    benefits
                    planPicker
                    purchaseButton
                    fineprint
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 28)
                .readableColumn(maxWidth: 520)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Kinvoy Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Restore") {
                        Task { await subscriptions.restore() }
                    }
                    .font(.footnote)
                }
            }
            .task {
                await subscriptions.loadProducts()
            }
            .onChange(of: subscriptions.premiumFamilyIds) {
                if subscriptions.hasPremium(familyId: familyStore.family?.id) {
                    dismiss()
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor)
            Text("Unlock everything for \(groupName)")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("One subscription covers your whole group — everyone gets Premium, nobody else pays.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 12)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefit("suitcase.fill", "Unlimited trips",
                    "Free covers one at a time. Plan next summer while this one's still going.")
            benefit("house.fill", "Unlimited groups",
                    "Free covers one. Add the in-laws, a friend group, the whole extended family.")
            benefit("checkmark.seal.fill", "Everything in every trip",
                    "Plans, chat, map, photos, expenses, packing lists, and AI ideas — in all of them.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func benefit(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var planPicker: some View {
        VStack(spacing: 10) {
            ForEach(subscriptions.products, id: \.id) { product in
                planRow(product)
            }
            if subscriptions.products.isEmpty {
                if subscriptions.didLoadProducts {
                    // Never leave a spinner running forever if the store is
                    // unreachable or the products aren't live yet.
                    VStack(spacing: 8) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Plans couldn't load right now.")
                            .font(.subheadline.weight(.medium))
                        Text("Check your connection and try again.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await subscriptions.loadProducts() }
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    ProgressView().padding(.vertical, 20)
                }
            }
        }
    }

    private func planRow(_ product: Product) -> some View {
        let isSelected = selectedID == product.id
        let isYearly = product.id == SubscriptionService.yearlyID
        return Button {
            selectedID = product.id
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(isYearly ? "Yearly" : "Monthly")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        if isYearly {
                            Text("BEST VALUE")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.accentColor, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    Text(priceLine(product))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }

    /// Spells out the billing period and any intro offer, as Apple requires.
    private func priceLine(_ product: Product) -> String {
        let period = product.id == SubscriptionService.yearlyID ? "per year, billed annually" : "per month, billed monthly"
        if let offer = product.subscription?.introductoryOffer, offer.paymentMode == .freeTrial {
            let unit = offer.period.unit == .day ? "day" : "week"
            let count = offer.period.value
            return "\(count)-\(unit) free trial, then \(product.displayPrice) \(period)"
        }
        return "\(product.displayPrice) \(period)"
    }

    private var purchaseButton: some View {
        VStack(spacing: 10) {
            Button {
                guard let product = subscriptions.product(for: selectedID),
                      let familyId = familyStore.family?.id else { return }
                Task { await subscriptions.purchase(product, familyId: familyId) }
            } label: {
                Group {
                    if subscriptions.isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(startButtonTitle)
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .disabled(subscriptions.isPurchasing || subscriptions.product(for: selectedID) == nil || familyStore.family == nil)

            if familyStore.family == nil {
                Text("Set up a group first — Premium applies to a group, not a person.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let error = subscriptions.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var startButtonTitle: String {
        if let product = subscriptions.product(for: selectedID),
           let offer = product.subscription?.introductoryOffer,
           offer.paymentMode == .freeTrial {
            return "Start free trial"
        }
        return "Subscribe"
    }

    private var fineprint: some View {
        VStack(spacing: 10) {
            Text("Payment is charged to your Apple Account at confirmation. Subscriptions renew automatically unless turned off at least 24 hours before the period ends. Manage or cancel anytime in Settings > Apple Account > Subscriptions. Any unused portion of a free trial is forfeited when you subscribe.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Link("Terms of Use", destination: URL(string: "https://kendallcoding202.github.io/kinvoy/terms.html")!)
                Link("Privacy Policy", destination: URL(string: "https://kendallcoding202.github.io/kinvoy/privacy.html")!)
            }
            .font(.caption)
        }
    }
}
