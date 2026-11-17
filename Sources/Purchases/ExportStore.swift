import Foundation

/// Export credits and Premium for the whole app. Injected at the app root as an environment object.
///
/// Rules (see `ExportEntitlementLogic` for the pure part):
/// - Credit is spent only by `recordCompletedExport`, after the system reported a finished share, save or print.
/// - A purchase adds exports only after the store verified it. Pending, cancelled, failed and unverified purchases add nothing.
/// - If the store cannot be reached, nothing is unlocked. The paywall says so and offers a retry.
/// - Premium and exports already bought work without a connection.
@MainActor
final class ExportStore: ObservableObject {
    enum CatalogState: Equatable {
        case idle
        case loading
        case ready
        /// The store could not be reached, or the products are not available.
        case unavailable
    }

    enum PurchaseOutcome: Equatable {
        case purchased
        case pending
        case cancelled
        case unverified
        case failed
    }

    enum RestoreOutcome: Equatable {
        /// Premium is active after the refresh.
        case premiumActive
        /// The store answered, and no Premium purchase was found.
        case nothingFound
        /// The store could not be reached or the person closed the sign-in.
        case failed
    }

    @Published private(set) var logic: ExportEntitlementLogic
    @Published private(set) var catalogState: CatalogState = .idle
    @Published private(set) var products: [String: StoreProduct] = [:]
    /// The product being bought right now, if any.
    @Published private(set) var busyProductID: String?
    @Published private(set) var isRestoring = false

    private let backend: StoreBackend
    private let storage: ExportEntitlementStorage
    private var listener: Task<Void, Never>?
    private var started = false

    init(backend: StoreBackend = StoreKitBackend(), storage: ExportEntitlementStorage = MirroredExportStorage.standard()) {
        self.backend = backend
        self.storage = storage
        self.logic = ExportEntitlementLogic.decoded(from: storage.load())
    }

    var credits: Int { logic.credits }
    var isPremium: Bool { logic.isPremium }
    var pack: StoreProduct? { products[ExportProduct.pack3] }
    var premium: StoreProduct? { products[ExportProduct.premium] }
    var isBusy: Bool { busyProductID != nil || isRestoring }

    // MARK: Start

    /// Starts listening for store updates and refreshes purchases and prices. Safe to call more than once.
    func start() {
        guard !started else { return }
        started = true
        let updates = backend.updates()
        listener = Task { [weak self] in
            for await transaction in updates {
                guard let self = self else { return }
                await self.process(transaction)
            }
        }
        Task { [weak self] in
            await self?.drainUnfinished()
            await self?.refreshPremium()
            await self?.loadProducts()
        }
    }

    // MARK: Prices

    func loadProducts() async {
        guard catalogState != .loading else { return }
        catalogState = .loading
        do {
            let list = try await backend.products(for: ExportProduct.all)
            var map: [String: StoreProduct] = [:]
            for product in list { map[product.id] = product }
            products = map
            catalogState = list.isEmpty ? .unavailable : .ready
        } catch {
            catalogState = .unavailable
        }
    }

    // MARK: Access and spending

    func access(for documentID: UUID, gate: ExportGate) -> ExportAccess {
        logic.access(hasAdGrant: gate.hasGrant(for: documentID))
    }

    /// Called only after a share, save or print really completed. Uses up one export (never when Premium is active).
    @discardableResult
    func recordCompletedExport(for documentID: UUID, gate: ExportGate) -> ExportSpend {
        let spend = logic.recordCompletedExport(hasAdGrant: gate.hasGrant(for: documentID))
        switch spend {
        case .adGrant:
            gate.consume(for: documentID)
        case .credit:
            persist()
        case .nothing:
            break
        }
        return spend
    }

    /// The one place that decides what a finished or unfinished export costs.
    /// Only `.completed` (the system reported that the file was really shared, saved or printed) uses up an export.
    /// Cancelled and failed outcomes use up nothing.
    @discardableResult
    func settle(_ outcome: ExportOutcome, for documentID: UUID, gate: ExportGate) -> ExportSpend {
        guard outcome == .completed else { return .nothing }
        return recordCompletedExport(for: documentID, gate: gate)
    }

    // MARK: Buying

    func purchase(_ productID: String) async -> PurchaseOutcome {
        guard busyProductID == nil, !isRestoring else { return .cancelled }
        busyProductID = productID
        defer { busyProductID = nil }
        do {
            switch try await backend.purchase(productID) {
            case .purchased(let transaction):
                await process(transaction)
                return .purchased
            case .pending:
                return .pending
            case .cancelled:
                return .cancelled
            case .unverified:
                return .unverified
            }
        } catch {
            return .failed
        }
    }

    /// Restore purchases. Premium comes back. Used-up export packs cannot be restored.
    func restore() async -> RestoreOutcome {
        guard busyProductID == nil, !isRestoring else { return .failed }
        isRestoring = true
        defer { isRestoring = false }
        var reached = true
        do {
            try await backend.sync()
        } catch {
            reached = false
        }
        await drainUnfinished()
        await refreshPremium()
        if logic.isPremium { return .premiumActive }
        return reached ? .nothingFound : .failed
    }

    // MARK: Transactions

    /// Applies one verified transaction, saves it, and only then tells the store it was delivered.
    func process(_ transaction: StoreTransaction) async {
        switch transaction.productID {
        case ExportProduct.pack3:
            if transaction.isRevoked {
                logic.applyRevocation(transactionID: transaction.id)
            } else {
                logic.applyPurchase(transactionID: transaction.id)
            }
            persist()
        case ExportProduct.premium:
            if transaction.isRevoked {
                await refreshPremium()
            } else {
                logic.setPremium(true)
                persist()
            }
        default:
            break
        }
        await transaction.finish()
    }

    private func drainUnfinished() async {
        let pending = await backend.unfinishedTransactions()
        for transaction in pending {
            await process(transaction)
        }
    }

    func refreshPremium() async {
        let ids = await backend.entitledProductIDs()
        logic.setPremium(ids.contains(ExportProduct.premium))
        persist()
    }

    private func persist() {
        if let data = try? logic.encoded() {
            storage.save(data)
        }
    }
}
