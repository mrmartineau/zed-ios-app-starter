import StoreKit
import SwiftUI

/// A minimal, honest paywall: what you get, what it costs, buy, restore.
///
/// Prices come from `Product.displayPrice`, which is already localised and
/// currency-correct — never hard-code a price string.
struct PaywallView: View {
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
                        Benefit(symbol: "heart", title: "Support development", detail: "One payment, no subscription.")
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

                    Text("Payment is charged to your Apple Account. Replace this with your own terms and privacy links before shipping.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
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
        }
        .padding(.top, Theme.Spacing.md)
    }

    @ViewBuilder
    private var buyButtons: some View {
        if store.products.isEmpty {
            ProgressView()
                .padding(.vertical, Theme.Spacing.md)
        } else {
            ForEach(store.products, id: \.id) { product in
                Button {
                    Task { await store.purchase(product) }
                } label: {
                    HStack {
                        Text(product.displayName)
                        Spacer()
                        Text(product.displayPrice).bold()
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
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PaywallView()
        .environment(StoreManager())
}
