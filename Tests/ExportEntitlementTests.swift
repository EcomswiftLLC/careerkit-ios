import XCTest
@testable import CareerKit

/// The pure rules: access order, purchases applied once, credit spent only after a finished export.
final class ExportEntitlementLogicTests: XCTestCase {
    func testNothingPurchasedIsLocked() {
        let logic = ExportEntitlementLogic()
        XCTAssertEqual(logic.credits, 0)
        XCTAssertEqual(logic.access(hasAdGrant: false), .locked)
        XCTAssertFalse(logic.access(hasAdGrant: false).isOpen)
    }

    func testAccessOrderIsPremiumThenVideoThenCredit() {
        XCTAssertEqual(ExportEntitlementLogic.resolve(isPremium: true, hasAdGrant: true, credits: 3), .premium)
        XCTAssertEqual(ExportEntitlementLogic.resolve(isPremium: false, hasAdGrant: true, credits: 3), .adGrant)
        XCTAssertEqual(ExportEntitlementLogic.resolve(isPremium: false, hasAdGrant: false, credits: 3), .credit)
        XCTAssertEqual(ExportEntitlementLogic.resolve(isPremium: false, hasAdGrant: false, credits: 0), .locked)
    }

    func testOnePackAddsThreeExports() {
        var logic = ExportEntitlementLogic()
        XCTAssertTrue(logic.applyPurchase(transactionID: 1))
        XCTAssertEqual(logic.credits, 3)
        XCTAssertEqual(ExportProduct.packSize, 3)
        XCTAssertEqual(logic.access(hasAdGrant: false), .credit)
    }

    func testTheSameTransactionIsAppliedOnlyOnce() {
        var logic = ExportEntitlementLogic()
        XCTAssertTrue(logic.applyPurchase(transactionID: 7))
        XCTAssertFalse(logic.applyPurchase(transactionID: 7))
        XCTAssertFalse(logic.applyPurchase(transactionID: 7))
        XCTAssertEqual(logic.credits, 3)
        XCTAssertTrue(logic.applyPurchase(transactionID: 8))
        XCTAssertEqual(logic.credits, 6)
    }

    func testCreditIsSpentOnlyByACompletedExportAndOnePerExport() {
        var logic = ExportEntitlementLogic()
        logic.applyPurchase(transactionID: 1)
        XCTAssertEqual(logic.credits, 3)   // having prepared or cancelled an export spends nothing
        XCTAssertEqual(logic.recordCompletedExport(hasAdGrant: false), .credit)
        XCTAssertEqual(logic.credits, 2)
        XCTAssertEqual(logic.recordCompletedExport(hasAdGrant: false), .credit)
        XCTAssertEqual(logic.recordCompletedExport(hasAdGrant: false), .credit)
        XCTAssertEqual(logic.credits, 0)
        XCTAssertEqual(logic.access(hasAdGrant: false), .locked)
        XCTAssertEqual(logic.recordCompletedExport(hasAdGrant: false), .nothing)
        XCTAssertEqual(logic.credits, 0, "credits never go below zero")
    }

    func testAVideoGrantIsSpentBeforeACredit() {
        var logic = ExportEntitlementLogic()
        logic.applyPurchase(transactionID: 1)
        XCTAssertEqual(logic.recordCompletedExport(hasAdGrant: true), .adGrant)
        XCTAssertEqual(logic.credits, 3, "the pack is untouched while a video grant covers the export")
    }

    func testPremiumSpendsNothing() {
        var logic = ExportEntitlementLogic()
        logic.applyPurchase(transactionID: 1)
        logic.setPremium(true)
        XCTAssertEqual(logic.access(hasAdGrant: false), .premium)
        XCTAssertEqual(logic.recordCompletedExport(hasAdGrant: false), .nothing)
        XCTAssertEqual(logic.recordCompletedExport(hasAdGrant: true), .nothing)
        XCTAssertEqual(logic.credits, 3)
    }

    func testRefundTakesAPackBackOnceAndNeverBelowZero() {
        var logic = ExportEntitlementLogic()
        logic.applyPurchase(transactionID: 1)
        logic.recordCompletedExport(hasAdGrant: false)
        logic.recordCompletedExport(hasAdGrant: false)
        logic.applyRevocation(transactionID: 1)
        XCTAssertEqual(logic.credits, 0)
        logic.applyRevocation(transactionID: 1)
        XCTAssertEqual(logic.credits, 0)
        XCTAssertFalse(logic.applyPurchase(transactionID: 1), "a redelivered refunded purchase adds nothing")
    }

    func testRefundBeforeDeliveryAddsNothing() {
        var logic = ExportEntitlementLogic()
        logic.applyRevocation(transactionID: 5)
        XCTAssertFalse(logic.applyPurchase(transactionID: 5))
        XCTAssertEqual(logic.credits, 0)
    }

    func testRememberedTransactionListsStayBounded() {
        var logic = ExportEntitlementLogic()
        for id in 0..<UInt64(ExportEntitlementLogic.maxRemembered + 50) {
            logic.applyPurchase(transactionID: id)
        }
        XCTAssertLessThanOrEqual(logic.handledTransactionIDs.count, ExportEntitlementLogic.maxRemembered)
    }

    func testEncodingRoundTripAndCorruptData() throws {
        var logic = ExportEntitlementLogic()
        logic.applyPurchase(transactionID: 42)
        logic.setPremium(true)
        let decoded = ExportEntitlementLogic.decoded(from: try logic.encoded())
        XCTAssertEqual(decoded, logic)
        XCTAssertEqual(ExportEntitlementLogic.decoded(from: nil), ExportEntitlementLogic())
        XCTAssertEqual(ExportEntitlementLogic.decoded(from: Data("not json".utf8)), ExportEntitlementLogic())
        XCTAssertEqual(ExportEntitlementLogic.decoded(from: Data("{}".utf8)), ExportEntitlementLogic())
    }

    func testProductIdsMatchAppStoreConnect() {
        XCTAssertEqual(ExportProduct.pack3, "export_pack_3")
        XCTAssertEqual(ExportProduct.premium, "premium_unlimited")
    }
}

// MARK: - Store with a fake backend

private final class FakeStoreBackend: StoreBackend {
    var productList: [StoreProduct] = [
        StoreProduct(id: ExportProduct.pack3, displayName: "Export pack", displayPrice: "$0.99"),
        StoreProduct(id: ExportProduct.premium, displayName: "Premium", displayPrice: "$9.99")
    ]
    var productsError: Error?
    /// Seconds the product request takes to answer (to test the loading timeout).
    var productsDelay: TimeInterval = 0
    var purchaseResult: StorePurchaseResult = .cancelled
    var purchaseError: Error?
    var entitled: Set<String> = []
    var unfinished: [StoreTransaction] = []
    var syncError: Error?
    var syncCalls = 0

    struct Offline: Error {}

    func products(for ids: [String]) async throws -> [StoreProduct] {
        // The answer is decided when the request starts, as a real store would, so a slow one can be stale.
        let answer = productList
        let failure = productsError
        if productsDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(productsDelay * 1_000_000_000))
        }
        if let error = failure { throw error }
        return answer
    }

    func purchase(_ productID: String) async throws -> StorePurchaseResult {
        if let error = purchaseError { throw error }
        return purchaseResult
    }

    func entitledProductIDs() async -> Set<String> { entitled }
    func unfinishedTransactions() async -> [StoreTransaction] { unfinished }
    func updates() -> AsyncStream<StoreTransaction> { AsyncStream { $0.finish() } }

    func sync() async throws {
        syncCalls += 1
        if let error = syncError { throw error }
    }
}

@MainActor
final class ExportStoreTests: XCTestCase {
    private var backend: FakeStoreBackend!
    private var storage: InMemoryExportStorage!
    private var gate: ExportGate!
    private let doc = UUID()

    override func setUp() async throws {
        backend = FakeStoreBackend()
        storage = InMemoryExportStorage()
        let name = "ExportStoreTests-" + UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: name) }
        gate = ExportGate(defaults: defaults, storageKey: "test.grants")
    }

    private func makeStore(loadTimeout: TimeInterval = ExportStore.defaultLoadTimeout) -> ExportStore {
        ExportStore(backend: backend, storage: storage, loadTimeout: loadTimeout)
    }

    private func packTransaction(id: UInt64, revoked: Bool = false, onFinish: (() -> Void)? = nil) -> StoreTransaction {
        StoreTransaction(id: id, productID: ExportProduct.pack3, isRevoked: revoked, finish: { onFinish?() })
    }

    func testVerifiedPackPurchaseAddsThreeExports() async {
        let store = makeStore()
        backend.purchaseResult = .purchased(packTransaction(id: 1))
        let outcome = await store.purchase(ExportProduct.pack3)
        XCTAssertEqual(outcome, .purchased)
        XCTAssertEqual(store.credits, 3)
        XCTAssertEqual(store.access(for: doc, gate: gate), .credit)
    }

    func testPurchaseIsSavedBeforeTheStoreIsToldItWasDelivered() async {
        let store = makeStore()
        var savedWhenFinished: Int?
        let storageRef = storage!
        backend.purchaseResult = .purchased(packTransaction(id: 1, onFinish: {
            savedWhenFinished = ExportEntitlementLogic.decoded(from: storageRef.load()).credits
        }))
        _ = await store.purchase(ExportProduct.pack3)
        XCTAssertEqual(savedWhenFinished, 3)
    }

    func testPendingCancelledUnverifiedAndFailedPurchasesAddNothing() async {
        let store = makeStore()
        let results: [(StorePurchaseResult, ExportStore.PurchaseOutcome)] = [
            (.pending, .pending), (.cancelled, .cancelled), (.unverified, .unverified)
        ]
        for (result, expected) in results {
            backend.purchaseResult = result
            let outcome = await store.purchase(ExportProduct.pack3)
            XCTAssertEqual(outcome, expected)
        }
        backend.purchaseError = FakeStoreBackend.Offline()
        let failed = await store.purchase(ExportProduct.pack3)
        XCTAssertEqual(failed, .failed)
        XCTAssertEqual(store.credits, 0)
        XCTAssertFalse(store.isPremium)
        XCTAssertEqual(store.access(for: doc, gate: gate), .locked)
    }

    func testStoreUnreachableUnlocksNothing() async {
        let store = makeStore()
        backend.productsError = FakeStoreBackend.Offline()
        await store.loadProducts()
        XCTAssertEqual(store.catalogState, .unavailable)
        XCTAssertNil(store.pack)
        XCTAssertEqual(store.access(for: doc, gate: gate), .locked)
        XCTAssertEqual(store.settle(.completed, for: doc, gate: gate), .nothing)
        XCTAssertEqual(store.credits, 0)
    }

    /// An empty catalog is its own state (not "could not be reached"). It never unlocks an export by itself and it
    /// stops the app from promising purchases, but it opens the free "Export without video" path.
    func testNoProductsIsItsOwnStateAndNeverUnlocksByItself() async {
        let store = makeStore()
        backend.productList = []
        await store.loadProducts()
        XCTAssertEqual(store.catalogState, .noProducts)
        XCTAssertNil(store.pack)
        XCTAssertNil(store.premium)
        XCTAssertFalse(store.offersPurchases)
        XCTAssertTrue(store.allowsExportWithoutVideo)
        XCTAssertEqual(store.access(for: doc, gate: gate), .locked, "no products never opens an export on its own")
        XCTAssertEqual(store.settle(.completed, for: doc, gate: gate), .nothing)
    }

    func testAnUnreachableStoreOffersPurchasesButNotTheFreeExport() async {
        let store = makeStore()
        backend.productsError = FakeStoreBackend.Offline()
        await store.loadProducts()
        XCTAssertEqual(store.catalogState, .unavailable)
        XCTAssertTrue(store.offersPurchases)
        XCTAssertFalse(store.allowsExportWithoutVideo, "an unreachable store never opens the free export")
    }

    func testBeforeTheFirstAnswerThePaywallStillTalksAboutPurchases() {
        let store = makeStore()
        XCTAssertEqual(store.catalogState, .idle)
        XCTAssertTrue(store.offersPurchases)
        XCTAssertFalse(store.allowsExportWithoutVideo)
    }

    func testProductsThatAppearLaterReplaceTheNoProductsState() async {
        let store = makeStore()
        backend.productList = []
        await store.loadProducts()
        XCTAssertEqual(store.catalogState, .noProducts)
        backend.productList = [StoreProduct(id: ExportProduct.pack3, displayName: "Export pack", displayPrice: "$0.99")]
        await store.loadProducts()
        XCTAssertEqual(store.catalogState, .ready)
        XCTAssertTrue(store.offersPurchases)
        XCTAssertFalse(store.allowsExportWithoutVideo)
    }

    func testPriceRequestThatNeverAnswersTimesOutInsteadOfLoadingForever() async throws {
        let store = makeStore(loadTimeout: 0.15)
        backend.productsDelay = 0.6
        let request = Task { await store.loadProducts() }
        try await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertEqual(store.catalogState, .loading)
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(store.catalogState, .unavailable, "after the timeout the paywall must offer a retry")
        XCTAssertFalse(store.allowsExportWithoutVideo)
        // A slow answer that still arrives is used.
        await request.value
        XCTAssertEqual(store.catalogState, .ready)
    }

    func testRetryAfterATimeoutIgnoresTheStaleAnswer() async throws {
        let store = makeStore(loadTimeout: 0.1)
        backend.productsDelay = 0.4
        let first = Task { await store.loadProducts() }
        try await Task.sleep(nanoseconds: 250_000_000)
        XCTAssertEqual(store.catalogState, .unavailable)
        backend.productsDelay = 0
        backend.productList = []
        await store.loadProducts()
        XCTAssertEqual(store.catalogState, .noProducts)
        // The first request finishes now with the old list and must not overwrite the newer answer.
        await first.value
        XCTAssertEqual(store.catalogState, .noProducts)
    }

    func testRestoreMessageIsAccurateWhileExportsAreLeft() {
        let none = ExportStore.nothingToRestoreMessage(credits: 0)
        let some = ExportStore.nothingToRestoreMessage(credits: 2)
        XCTAssertNotEqual(none, some)
        XCTAssertTrue(none.contains("used up"))
        XCTAssertFalse(some.contains("used up"), "exports that are still left are not used up")
        XCTAssertTrue(some.contains("kept on this device"))
    }

    func testPricesComeFromTheStore() async {
        let store = makeStore()
        await store.loadProducts()
        XCTAssertEqual(store.catalogState, .ready)
        XCTAssertEqual(store.pack?.displayPrice, "$0.99")
        XCTAssertEqual(store.premium?.displayPrice, "$9.99")
    }

    func testOnlyACompletedExportSpendsACredit() async {
        let store = makeStore()
        backend.purchaseResult = .purchased(packTransaction(id: 1))
        _ = await store.purchase(ExportProduct.pack3)

        XCTAssertEqual(store.settle(.cancelled, for: doc, gate: gate), .nothing)
        XCTAssertEqual(store.credits, 3)
        XCTAssertEqual(store.settle(.failed, for: doc, gate: gate), .nothing)
        XCTAssertEqual(store.credits, 3)

        XCTAssertEqual(store.settle(.completed, for: doc, gate: gate), .credit)
        XCTAssertEqual(store.credits, 2)
    }

    func testSpentCreditsSurviveARelaunch() async {
        let store = makeStore()
        backend.purchaseResult = .purchased(packTransaction(id: 1))
        _ = await store.purchase(ExportProduct.pack3)
        store.settle(.completed, for: doc, gate: gate)
        let relaunched = makeStore()
        XCTAssertEqual(relaunched.credits, 2)
    }

    func testAVideoGrantIsUsedBeforeACreditAndConsumedOnCompletion() async {
        let store = makeStore()
        backend.purchaseResult = .purchased(packTransaction(id: 1))
        _ = await store.purchase(ExportProduct.pack3)
        gate.grant(for: doc)
        XCTAssertEqual(store.access(for: doc, gate: gate), .adGrant)
        XCTAssertEqual(store.settle(.completed, for: doc, gate: gate), .adGrant)
        XCTAssertFalse(gate.hasGrant(for: doc))
        XCTAssertEqual(store.credits, 3)
    }

    func testRedeliveredTransactionIsCountedOnce() async {
        let store = makeStore()
        var finishCalls = 0
        let transaction = packTransaction(id: 9, onFinish: { finishCalls += 1 })
        await store.process(transaction)
        await store.process(transaction)
        XCTAssertEqual(store.credits, 3)
        XCTAssertEqual(finishCalls, 2, "a delivered transaction is always finished, even when it was already counted")
    }

    func testUnfinishedPurchaseFromARunThatCrashedIsDeliveredAtLaunch() async {
        let store = makeStore()
        backend.unfinished = [packTransaction(id: 11)]
        store.start()
        for _ in 0..<50 where store.credits == 0 { try? await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertEqual(store.credits, 3)
    }

    func testRefundTakesTheExportsBack() async {
        let store = makeStore()
        await store.process(packTransaction(id: 3))
        await store.process(packTransaction(id: 3, revoked: true))
        XCTAssertEqual(store.credits, 0)
    }

    func testPremiumFromTheStoreOpensEveryExportAndSpendsNothing() async {
        let store = makeStore()
        backend.entitled = [ExportProduct.premium]
        await store.refreshPremium()
        XCTAssertTrue(store.isPremium)
        XCTAssertEqual(store.access(for: doc, gate: gate), .premium)
        XCTAssertEqual(store.settle(.completed, for: doc, gate: gate), .nothing)
    }

    func testPremiumIsRemovedWhenTheStoreNoLongerReportsIt() async {
        let store = makeStore()
        backend.entitled = [ExportProduct.premium]
        await store.refreshPremium()
        backend.entitled = []
        await store.refreshPremium()
        XCTAssertFalse(store.isPremium)
        XCTAssertEqual(store.access(for: doc, gate: gate), .locked)
    }

    func testRestoreBringsPremiumBack() async {
        let store = makeStore()
        backend.entitled = [ExportProduct.premium]
        let outcome = await store.restore()
        XCTAssertEqual(outcome, .premiumActive)
        XCTAssertEqual(backend.syncCalls, 1)
        XCTAssertTrue(store.isPremium)
    }

    func testRestoreWithNothingToRestoreAndWithAnUnreachableStore() async {
        let store = makeStore()
        let none = await store.restore()
        XCTAssertEqual(none, .nothingFound)
        backend.syncError = FakeStoreBackend.Offline()
        let failed = await store.restore()
        XCTAssertEqual(failed, .failed)
        XCTAssertEqual(store.access(for: doc, gate: gate), .locked)
        XCTAssertEqual(store.credits, 0)
    }

    func testStorageFallbackKeepsPurchasesWhenOneStoreIsEmpty() throws {
        let primary = InMemoryExportStorage()
        let secondary = InMemoryExportStorage()
        let mirrored = MirroredExportStorage(primary: primary, secondary: secondary)
        var logic = ExportEntitlementLogic()
        logic.applyPurchase(transactionID: 1)
        mirrored.save(try logic.encoded())
        // Keychain item gone: the copy still has the purchase.
        let onlyCopy = MirroredExportStorage(primary: InMemoryExportStorage(), secondary: secondary)
        XCTAssertEqual(ExportEntitlementLogic.decoded(from: onlyCopy.load()).credits, 3)
    }
}
