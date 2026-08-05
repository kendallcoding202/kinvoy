import Foundation
import StoreKit
import Supabase
import SwiftUI

/// Kinvoy Premium. The entitlement belongs to the group, so one member
/// subscribes and everyone in that group gets Premium.
@MainActor
final class SubscriptionService: ObservableObject {
    /// Master switch. While false every feature is unlocked for everyone and
    /// no paywall is shown. Set true once the subscription products exist in
    /// App Store Connect — otherwise the paywall renders with no plans.
    static let paywallEnabled = true

    static let monthlyID = "com.kendallsorenson.getaway.premium.monthly"
    static let yearlyID = "com.kendallsorenson.getaway.premium.yearly"

    @Published private(set) var products: [Product] = []
    /// Nil until a load has been attempted, so the paywall can tell
    /// "still loading" from "the store gave us nothing".
    @Published private(set) var didLoadProducts = false
    @Published private(set) var premiumFamilyIds: Set<UUID> = []
    @Published var isPurchasing = false
    @Published var lastError: String?

    private var client: SupabaseClient { SupabaseService.shared.client }
    private var updatesTask: Task<Void, Never>?

    init() {
        // Renewals and purchases made on other devices arrive here.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self, case .verified(let transaction) = update else { continue }
                await self.syncRenewal(update, transaction: transaction)
                await transaction.finish()
            }
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Entitlement

    /// True when this group has Premium — or when the paywall is still off.
    func hasPremium(familyId: UUID?) -> Bool {
        if !Self.paywallEnabled { return true }
        guard let familyId else { return false }
        return premiumFamilyIds.contains(familyId)
    }

    /// The server is the source of truth; the client only reads it.
    func refreshEntitlements() async {
        guard AppConfig.isConfigured, SupabaseService.shared.userId != nil else { return }
        do {
            let ids: [UUID] = try await client.rpc("my_premium_families").execute().value
            premiumFamilyIds = Set(ids)
        } catch {
            print("Entitlement refresh failed: \(error)")
        }
    }

    // MARK: - Store

    func loadProducts() async {
        defer { didLoadProducts = true }
        do {
            products = try await Product.products(for: [Self.monthlyID, Self.yearlyID])
                .sorted { $0.price < $1.price }
        } catch {
            print("Product load failed: \(error)")
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    func purchase(_ product: Product, familyId: UUID) async {
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = "That purchase couldn't be verified."
                    return
                }
                await activate(jws: verification.jwsRepresentation, familyId: familyId)
                await transaction.finish()
            case .userCancelled:
                break
            case .pending:
                lastError = "Your purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            lastError = "The purchase didn't go through. Please try again."
        }
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        try? await AppStore.sync()
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement else { continue }
            await syncRenewal(entitlement, transaction: transaction)
        }
        await refreshEntitlements()
    }

    // MARK: - Server sync

    /// Sends the signed transaction (JWS) to the Edge Function, which
    /// validates it and writes the entitlement with the service role.
    private func activate(jws: String, familyId: UUID) async {
        struct Payload: Encodable {
            let family_id: String
            let signed_transaction: String
        }
        do {
            _ = try await client.functions.invoke(
                "verify-subscription",
                options: FunctionInvokeOptions(body: Payload(
                    family_id: familyId.uuidString,
                    signed_transaction: jws
                ))
            ) as Data
            await refreshEntitlements()
        } catch {
            lastError = "Purchase went through, but activating Premium failed. Try Restore Purchases."
            print("Activation failed: \(error)")
        }
    }

    /// Renewals and restores don't say which group they paid for, so look up
    /// the group by the original transaction id we stored at purchase time.
    private func syncRenewal(_ verification: VerificationResult<StoreKit.Transaction>, transaction: StoreKit.Transaction) async {
        struct Row: Decodable { let family_id: UUID }
        let originalId = String(transaction.originalID)
        do {
            let rows: [Row] = try await client
                .from("subscriptions").select("family_id")
                .eq("original_transaction_id", value: originalId)
                .limit(1)
                .execute().value
            if let familyId = rows.first?.family_id {
                await activate(jws: verification.jwsRepresentation, familyId: familyId)
                return
            }
        } catch {
            print("Renewal lookup failed: \(error)")
        }
        await refreshEntitlements()
    }
}
