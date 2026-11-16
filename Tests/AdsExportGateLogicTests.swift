import XCTest
@testable import CareerKit

final class AdsExportGateLogicTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let docA = UUID()
    private let docB = UUID()

    func testNoGrantByDefault() {
        let logic = ExportGateLogic()
        XCTAssertFalse(logic.hasGrant(for: docA, now: t0))
    }

    func testGrantThenHasGrant() {
        var logic = ExportGateLogic()
        logic.grant(for: docA, now: t0)
        XCTAssertTrue(logic.hasGrant(for: docA, now: t0))
        XCTAssertTrue(logic.hasGrant(for: docA, now: t0.addingTimeInterval(3600)))
    }

    func testConsumeIsOneTime() {
        var logic = ExportGateLogic()
        logic.grant(for: docA, now: t0)
        XCTAssertTrue(logic.consume(for: docA, now: t0.addingTimeInterval(10)))
        XCTAssertFalse(logic.hasGrant(for: docA, now: t0.addingTimeInterval(11)))
        XCTAssertFalse(logic.consume(for: docA, now: t0.addingTimeInterval(12)))
    }

    func testConsumeWithoutGrantReturnsFalse() {
        var logic = ExportGateLogic()
        XCTAssertFalse(logic.consume(for: docA, now: t0))
    }

    func testGrantExpiresAfter24Hours() {
        var logic = ExportGateLogic()
        logic.grant(for: docA, now: t0)
        let justBefore = t0.addingTimeInterval(ExportGateLogic.lifetime - 1)
        let atExpiry = t0.addingTimeInterval(ExportGateLogic.lifetime)
        XCTAssertTrue(logic.hasGrant(for: docA, now: justBefore))
        XCTAssertFalse(logic.hasGrant(for: docA, now: atExpiry))
        XCTAssertFalse(logic.consume(for: docA, now: atExpiry), "An expired grant must not count as a valid export")
    }

    func testPerDocumentIsolation() {
        var logic = ExportGateLogic()
        logic.grant(for: docA, now: t0)
        XCTAssertTrue(logic.hasGrant(for: docA, now: t0))
        XCTAssertFalse(logic.hasGrant(for: docB, now: t0))
        logic.grant(for: docB, now: t0)
        logic.consume(for: docA, now: t0)
        XCTAssertFalse(logic.hasGrant(for: docA, now: t0))
        XCTAssertTrue(logic.hasGrant(for: docB, now: t0), "Consuming one document must not touch another")
    }

    func testDuplicateGrantDoesNotStack() {
        var logic = ExportGateLogic()
        logic.grant(for: docA, now: t0)
        logic.grant(for: docA, now: t0.addingTimeInterval(60))
        XCTAssertEqual(logic.grants.filter { $0.documentID == docA }.count, 1)
        XCTAssertTrue(logic.consume(for: docA, now: t0.addingTimeInterval(120)))
        XCTAssertFalse(logic.hasGrant(for: docA, now: t0.addingTimeInterval(121)), "One reward must give exactly one export")
    }

    func testDuplicateGrantDoesNotExtendExpiry() {
        var logic = ExportGateLogic()
        logic.grant(for: docA, now: t0)
        logic.grant(for: docA, now: t0.addingTimeInterval(3600))
        let expiry = logic.expiryDate(for: docA, now: t0.addingTimeInterval(3600))
        XCTAssertEqual(expiry, t0.addingTimeInterval(ExportGateLogic.lifetime))
    }

    func testNewGrantAfterExpiryReplacesOldOne() {
        var logic = ExportGateLogic()
        logic.grant(for: docA, now: t0)
        let later = t0.addingTimeInterval(ExportGateLogic.lifetime + 5)
        XCTAssertFalse(logic.hasGrant(for: docA, now: later))
        logic.grant(for: docA, now: later)
        XCTAssertTrue(logic.hasGrant(for: docA, now: later))
        XCTAssertEqual(logic.grants.count, 1)
    }

    func testFutureDatedGrantIsRejected() {
        let future = ExportGateLogic.Grant(documentID: docA, grantedAt: t0.addingTimeInterval(3 * 3600))
        let logic = ExportGateLogic(grants: [future])
        XCTAssertFalse(logic.hasGrant(for: docA, now: t0), "A moved-back clock must not extend a grant")
    }

    func testPurgeRemovesExpired() {
        var logic = ExportGateLogic()
        logic.grant(for: docA, now: t0)
        logic.grant(for: docB, now: t0.addingTimeInterval(ExportGateLogic.lifetime - 100))
        logic.purgeExpired(now: t0.addingTimeInterval(ExportGateLogic.lifetime + 1))
        XCTAssertEqual(logic.grants.map { $0.documentID }, [docB])
    }

    func testForgetRemovesGrant() {
        var logic = ExportGateLogic()
        logic.grant(for: docA, now: t0)
        logic.forget(documentID: docA)
        XCTAssertFalse(logic.hasGrant(for: docA, now: t0))
    }

    func testStoredGrantsAreCapped() {
        var logic = ExportGateLogic()
        for _ in 0..<(ExportGateLogic.maxStoredGrants + 25) {
            logic.grant(for: UUID(), now: t0)
        }
        XCTAssertEqual(logic.grants.count, ExportGateLogic.maxStoredGrants)
    }

    func testEncodeDecodeRoundTrip() throws {
        var logic = ExportGateLogic()
        logic.grant(for: docA, now: t0)
        logic.grant(for: docB, now: t0.addingTimeInterval(30))
        let data = try logic.encoded()
        let decoded = ExportGateLogic.decoded(from: data)
        XCTAssertEqual(decoded, logic)
        XCTAssertTrue(decoded.hasGrant(for: docA, now: t0.addingTimeInterval(40)))
    }

    func testCorruptOrMissingDataGivesEmptyLogic() {
        XCTAssertEqual(ExportGateLogic.decoded(from: nil), ExportGateLogic())
        XCTAssertEqual(ExportGateLogic.decoded(from: Data("not json".utf8)), ExportGateLogic())
    }
}

/// Persistence of the observable wrapper, using a private UserDefaults suite.
@MainActor
final class AdsExportGatePersistenceTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ck.tests.exportgate.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    func testGrantSurvivesRelaunch() {
        let id = UUID()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let first = ExportGate(defaults: defaults, now: { now })
        XCTAssertFalse(first.hasGrant(for: id))
        first.grant(for: id)
        XCTAssertTrue(first.hasGrant(for: id))

        let second = ExportGate(defaults: defaults, now: { now.addingTimeInterval(60) })
        XCTAssertTrue(second.hasGrant(for: id), "A grant must survive an app restart")
    }

    func testConsumeSurvivesRelaunch() {
        let id = UUID()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let first = ExportGate(defaults: defaults, now: { now })
        first.grant(for: id)
        first.consume(for: id)

        let second = ExportGate(defaults: defaults, now: { now.addingTimeInterval(60) })
        XCTAssertFalse(second.hasGrant(for: id))
    }

    func testExpiredGrantIsGoneAfterRelaunch() {
        let id = UUID()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let first = ExportGate(defaults: defaults, now: { now })
        first.grant(for: id)

        let later = now.addingTimeInterval(ExportGateLogic.lifetime + 1)
        let second = ExportGate(defaults: defaults, now: { later })
        XCTAssertFalse(second.hasGrant(for: id))
    }
}
