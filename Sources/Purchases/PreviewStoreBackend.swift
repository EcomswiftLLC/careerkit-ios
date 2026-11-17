import Foundation

extension ExportStore {
    /// The store the app starts with. Debug screenshot runs use fixed sample prices so the paywall can be captured
    /// in CI, where the simulator has no App Store products. Release builds always use StoreKit.
    @MainActor
    static func makeForLaunch() -> ExportStore {
        #if DEBUG
        if CKScreenshotSupport.isActive {
            return ExportStore(backend: PreviewStoreBackend(), storage: InMemoryExportStorage())
        }
        #endif
        return ExportStore()
    }
}

#if DEBUG
/// Debug only. Shows sample prices and never completes a purchase.
final class PreviewStoreBackend: StoreBackend {
    func products(for ids: [String]) async throws -> [StoreProduct] {
        [
            StoreProduct(id: ExportProduct.pack3, displayName: "Export pack", displayPrice: "$0.99"),
            StoreProduct(id: ExportProduct.premium, displayName: "Premium", displayPrice: "$9.99")
        ]
    }

    func purchase(_ productID: String) async throws -> StorePurchaseResult { .cancelled }
    func entitledProductIDs() async -> Set<String> { [] }
    func unfinishedTransactions() async -> [StoreTransaction] { [] }
    func updates() -> AsyncStream<StoreTransaction> { AsyncStream { $0.finish() } }
    func sync() async throws {}
}
#endif
