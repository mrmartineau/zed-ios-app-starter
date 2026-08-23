import Foundation
import StoreKit

/// StoreKit 2 wrapper: loads products, runs purchases, and tracks what the user
/// currently owns.
///
/// The whole file is inert until `start()` is called, which only happens when
/// `AppFeatures.purchases` is on — so it costs nothing in a project that
/// doesn't sell anything.
///
/// ## The three things every StoreKit integration must get right
///
/// 1. **A transaction listener that outlives any one screen.** Purchases can
///    complete while the app is backgrounded, on another device, or as an
///    Ask-to-Buy approval days later. `start()` opens `Transaction.updates`
///    for the life of the process; a listener owned by a paywall screen would
///    miss all of those.
/// 2. **Entitlements as the source of truth, not the purchase result.**
///    `Transaction.currentEntitlements` is what the user owns *now*, restores
///    and family sharing included. A local "did they buy it" flag drifts.
/// 3. **Finishing transactions.** An unfinished transaction is replayed on
///    every launch forever. `finish()` is what tells StoreKit it was delivered.
///
/// ## Before shipping
///
/// - Create matching products in App Store Connect using the IDs in
///   `ProductID` and in `Store/Products.storekit`.
/// - Add the In-App Purchase capability to the target.
/// - For anything more than a one-off unlock — subscriptions, refund handling,
///   cross-device state — verify receipts server-side rather than trusting the
///   device. `Transaction` is cryptographically signed and StoreKit verifies
///   it, but the device can still be lied to about *your* server's opinion.
///   `configure(accountID:report:)` is the hook for that; see its notes.
@Observable
@MainActor
final class StoreManager {
    /// Product identifiers, kept in one place so the `.storekit` file, App
    /// Store Connect and the code can't drift apart.
    ///
    /// Two products of different *shapes* — one auto-renewable subscription and
    /// one non-consumable — because that pair is what most small apps end up
    /// selling, and because the two have genuinely different rules. A
    /// subscription drags in the disclosure requirements handled in
    /// `PaywallView`, renewal and lapsing, and a server that wants to know about
    /// both. Delete whichever one a project doesn't sell.
    enum ProductID {
        static let annual = "wtf.zander.AppStarter.pro.annual"
        static let lifetime = "wtf.zander.AppStarter.pro.lifetime"

        static let all = [annual, lifetime]
    }

    /// Loaded from the App Store (or the local `.storekit` file in the
    /// simulator). Empty until `start()` finishes.
    private(set) var products: [Product] = []

    /// Product IDs the user currently owns.
    private(set) var purchasedIDs: Set<String> = []

    /// Set when a load or purchase fails, for the paywall to display.
    private(set) var errorMessage: String?

    /// `true` while a purchase is in flight, so the paywall can show a spinner
    /// and avoid double-taps.
    private(set) var isPurchasing = false

    /// The single entitlement check the rest of the app uses. Add a computed
    /// property per entitlement rather than checking raw IDs at call sites.
    ///
    /// Either product grants Pro, so this asks whether anything is owned rather
    /// than naming an ID. Once there are tiers that differ — a cheap one and a
    /// dear one that unlocks more — this splits into one property per tier and
    /// each names its own IDs.
    ///
    /// Local, and therefore only half the answer once a server is involved: the
    /// server decides what a paid feature actually does. This is for drawing the
    /// paywall, not for granting anything.
    var hasPro: Bool { !purchasedIDs.isEmpty }

    /// The signed-in account, stamped onto purchases as Apple's
    /// `appAccountToken`.
    ///
    /// This is what lets a server attribute a subscription safely: Apple hands
    /// the token back through its Server API, so the server hears which account
    /// bought something from Apple rather than from the device. Without it,
    /// linking a purchase would mean trusting a client's claim about an id that
    /// isn't secret.
    ///
    /// It can only be attached at purchase time — Apple won't add it to a
    /// transaction afterwards — which is why sign-in has to be wired to
    /// `configure` before anyone can reach the paywall.
    @ObservationIgnored private var accountID: UUID?

    /// How a server is told about a transaction, if there is one. Receives the
    /// `originalID`, which is the id that identifies a subscription across all
    /// of its renewals — the one Apple's Server API takes.
    @ObservationIgnored private var report: ((UInt64) async -> Void)?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    /// Call when sign-in state changes, before the paywall can be reached.
    ///
    /// Both values are optional and independent: an app with no accounts passes
    /// neither and everything below still works, an app with a backend passes
    /// both. What it should *not* do is pass an account id with no way to report
    /// it — the token would be stamped onto purchases that nothing ever reads.
    ///
    /// The reporting closure is deliberately a closure rather than a network
    /// call in this file. What the server wants — an endpoint, an auth header, a
    /// response shape — is a per-project decision, and this type has no business
    /// knowing it.
    func configure(accountID: String? = nil, report: ((UInt64) async -> Void)? = nil) {
        self.accountID = accountID.flatMap(UUID.init(uuidString:))
        self.report = report
    }

    deinit { updatesTask?.cancel() }

    /// Call once at launch. Starts the transaction listener, then loads
    /// products and current entitlements.
    func start() async {
        guard updatesTask == nil else { return }

        // Started before the first `await` below so a transaction that lands
        // during product loading isn't missed.
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                await self.handle(result)
            }
        }

        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        do {
            // Sorted by price so the paywall's ordering is stable rather than
            // whatever order the App Store happened to return.
            products = try await Product.products(for: ProductID.all)
                .sorted { $0.price < $1.price }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load products. Check your connection and try again."
        }
    }

    /// Runs the purchase sheet. Returns `true` only if the purchase completed
    /// and was verified — cancellation and pending approval both return
    /// `false`, which is why the paywall shouldn't treat `false` as an error.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            // The token is what makes the purchase attributable server-side, so
            // it goes on at purchase time or never — Apple won't add it later.
            var options: Set<Product.PurchaseOption> = []
            if let accountID { options.insert(.appAccountToken(accountID)) }

            switch try await product.purchase(options: options) {
            case .success(let verification):
                await handle(verification)
                return purchasedIDs.contains(product.id)

            case .userCancelled:
                return false

            case .pending:
                // Ask to Buy, or a payment method needing approval. The
                // transaction arrives later on `Transaction.updates`.
                errorMessage = "Waiting for approval. You'll get access once it's confirmed."
                return false

            @unknown default:
                return false
            }
        } catch {
            errorMessage = "The purchase couldn't be completed."
            return false
        }
    }

    /// Restores previous purchases.
    ///
    /// `AppStore.sync()` forces a fresh check with the App Store and may prompt
    /// for a password, so it belongs behind an explicit button — not at launch.
    /// Apple requires a restore affordance for non-consumables.
    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = "Couldn't restore purchases."
        }
    }

    /// Rebuilds `purchasedIDs` from what the user actually owns right now.
    func refreshEntitlements() async {
        var owned: Set<String> = []
        var originalIDs: Set<UInt64> = []

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            // A revoked purchase (refund, family sharing removed) still appears
            // here, so access must be withdrawn explicitly.
            if transaction.revocationDate == nil {
                owned.insert(transaction.productID)
                originalIDs.insert(transaction.originalID)
            }
        }
        purchasedIDs = owned

        // The recovery path for a notification Apple dropped. Reporting what the
        // device can see lets a server go and ask Apple about it, which is how
        // an account that has quietly lapsed — or quietly renewed — gets put
        // right without the user doing anything.
        for originalID in originalIDs {
            await report?(originalID)
        }
    }

    /// Grants access for a verified transaction and finishes it.
    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            // `.unverified` means StoreKit couldn't validate the signature —
            // treat it as no purchase and do not finish it.
            errorMessage = "That purchase couldn't be verified."
            return
        }

        await refreshEntitlements()
        await report?(transaction.originalID)

        // Finished only after any server has been told. A transaction that isn't
        // finished is replayed on the next launch, which is exactly the
        // behaviour wanted if this device dies mid-flow: the purchase gets
        // another chance to reach the server rather than being dropped.
        await transaction.finish()
    }

    func clearError() { errorMessage = nil }
}
