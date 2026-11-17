import Foundation
import StoreKit

/// A product as the paywall needs it. The price text always comes from the store, never from code.
struct StoreProduct: Equatable, Identifiable {
    let id: String
    let displayName: String
    let displayPrice: String
}

/// A verified store transaction, reduced to what the gate needs.
struct StoreTransaction {
    let id: UInt64
    let productID: String
    let isRevoked: Bool
    /// Tells the store the app has delivered the purchase. Called only after the purchase was saved.
    let finish: () async -> Void
}

enum StorePurchaseResult {
    case purchased(StoreTransaction)
    /// Waiting for approval (for example Ask to Buy). The transaction arrives later through `updates()`.
    case pending
    case cancelled
    /// The store could not verify the purchase. Never counts as a purchase.
    case unverified
}

enum StoreBackendError: Error {
    case productNotLoaded
}

/// Everything the export gate needs from the App Store, so the gate can be tested with a fake.
protocol StoreBackend: AnyObject {
    func products(for ids: [String]) async throws -> [StoreProduct]
    func purchase(_ productID: String) async throws -> StorePurchaseResult
    /// Product ids of non-consumable purchases that are currently valid for this Apple Account.
    func entitledProductIDs() async -> Set<String>
    /// Verified transactions the app has not finished yet (for example paid for while the app was closed).
    func unfinishedTransactions() async -> [StoreTransaction]
    /// Verified transactions that arrive outside a purchase call (Ask to Buy approval, refunds, other devices).
    func updates() -> AsyncStream<StoreTransaction>
    /// Asks the App Store to refresh purchases (Restore purchases). Throws when it cannot be reached.
    func sync() async throws
}

/// The real StoreKit 2 backend.
final class StoreKitBackend: StoreBackend {
    private var loaded: [String: Product] = [:]

    init() {}

    func products(for ids: [String]) async throws -> [StoreProduct] {
        let found = try await Product.products(for: ids)
        for product in found {
            loaded[product.id] = product
        }
        return found.map { StoreProduct(id: $0.id, displayName: $0.displayName, displayPrice: $0.displayPrice) }
    }

    func purchase(_ productID: String) async throws -> StorePurchaseResult {
        guard let product = loaded[productID] else { throw StoreBackendError.productNotLoaded }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                return .purchased(Self.convert(transaction))
            case .unverified:
                return .unverified
            }
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func entitledProductIDs() async -> Set<String> {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                ids.insert(transaction.productID)
            }
        }
        return ids
    }

    func unfinishedTransactions() async -> [StoreTransaction] {
        var items: [StoreTransaction] = []
        for await result in Transaction.unfinished {
            if case .verified(let transaction) = result {
                items.append(Self.convert(transaction))
            }
        }
        return items
    }

    func updates() -> AsyncStream<StoreTransaction> {
        AsyncStream { continuation in
            let task = Task {
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result {
                        continuation.yield(Self.convert(transaction))
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func sync() async throws {
        try await AppStore.sync()
    }

    private static func convert(_ transaction: Transaction) -> StoreTransaction {
        StoreTransaction(
            id: transaction.id,
            productID: transaction.productID,
            isRevoked: transaction.revocationDate != nil,
            finish: { await transaction.finish() }
        )
    }
}
