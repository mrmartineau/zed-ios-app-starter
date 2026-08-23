import StoreKit
import SwiftUI

/// What a subscription costs and what it buys.
///
/// Two products with different shapes — a subscription that renews and a
/// one-off that doesn't — so the screen says which is which rather than
/// presenting two prices and leaving you to work it out.
///
/// ## The disclosures are not decoration
///
/// App Review guideline 3.1.2 requires an auto-renewable subscription to state,
/// *on the screen that sells it*: the title, the length of a period, the price
/// per period, that it renews unless cancelled, and working links to a privacy
/// policy and terms. Apps get rejected for missing any of them. Everything below
/// `disclosure` is there for that reason, and prices come from
/// `Product.displayPrice` so they're localised and correct rather than a string
/// that drifts from what Apple actually charges.
///
/// An app selling only a non-consumable doesn't need the renewal sentence — but
/// it still needs the two links, so keep `disclosure` and trim the paragraph.
struct PaywallView: View {
    /// Replace both before shipping. App Review follows them, finds a 404, and
    /// rejects the build — this is one of the most common reasons a first
    /// submission with a subscription comes back.
    private static let termsURL = URL(string: "https://example.com/terms")!
    private static let privacyURL = URL(string: "https://example.com/privacy")!

    @Environment(StoreManager.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    header

                    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                        Benefit(symbol: "infinity", title: "Unlimited items", detail: "No cap on what you can save.")
                        Benefit(symbol: "icloud", title: "Sync", detail: "Keep everything in step across devices.")
                        Benefit(symbol: "heart", title: "Support development", detail: "Built by one person, with no adverts.")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()

                    if let message = store.errorMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    buyButtons

                    Button("Restore purchases") {
                        Task { await store.restore() }
                    }
                    .font(.footnote)

                    disclosure
                }
                .padding(Theme.Spacing.md)
            }
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                store.clearError()
                if store.products.isEmpty {
                    await store.loadProducts()
                }
            }
            // Close as soon as the entitlement lands, whether that came from
            // this purchase or a restore.
            .onChange(of: store.hasPro) { _, unlocked in
                if unlocked { dismiss() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            Text("Unlock everything")
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text("Replace this line with what the free tier stops at.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Spacing.md)
    }

    @ViewBuilder
    private var buyButtons: some View {
        if store.products.isEmpty {
            ProgressView()
                .padding(.vertical, Theme.Spacing.md)
        } else {
            VStack(spacing: Theme.Spacing.sm) {
                ForEach(store.products, id: \.id) { product in
                    Button {
                        Task { await store.purchase(product) }
                    } label: {
                        VStack(spacing: 2) {
                            HStack {
                                Text(product.displayName)
                                Spacer()
                                Text(product.displayPrice).bold()
                            }
                            // Says what the price actually means. "£19.99" alone
                            // doesn't distinguish a yearly charge from a one-off,
                            // which is exactly the confusion 3.1.2 exists to stop.
                            HStack {
                                Text(terms(for: product))
                                    .font(.caption)
                                    .opacity(0.85)
                                Spacer()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(store.isPurchasing)
                }
            }
        }
    }

    /// "Billed yearly, renews automatically" / "One payment, yours for good".
    ///
    /// Derived from the product rather than hard-coded per ID, so adding a
    /// monthly tier later needs no change here.
    private func terms(for product: Product) -> String {
        guard let period = product.subscription?.subscriptionPeriod else {
            return "One payment, yours for good"
        }

        let length: String
        switch period.unit {
        case .year: length = period.value == 1 ? "yearly" : "every \(period.value) years"
        case .month: length = period.value == 1 ? "monthly" : "every \(period.value) months"
        case .week: length = period.value == 1 ? "weekly" : "every \(period.value) weeks"
        case .day: length = period.value == 1 ? "daily" : "every \(period.value) days"
        @unknown default: length = "periodically"
        }
        return "Billed \(length), renews automatically"
    }

    private var disclosure: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(
                """
                Payment is charged to your Apple Account at confirmation. A subscription renews automatically unless it's cancelled at least 24 hours before the end of the current period, and your Apple Account is charged for renewal within 24 hours of the period ending. Manage or cancel in Settings › your name › Subscriptions. The lifetime purchase is a single payment and does not renew.
                """
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            HStack(spacing: Theme.Spacing.md) {
                Link("Terms of use", destination: Self.termsURL)
                Link("Privacy policy", destination: Self.privacyURL)
            }
            .font(.caption)
        }
    }
}

private struct Benefit: View {
    var symbol: String
    var title: String
    var detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(Theme.accent)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PaywallView()
        .environment(StoreManager())
}
