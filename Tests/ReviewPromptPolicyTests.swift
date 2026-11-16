import XCTest
@testable import CareerKit

private final class FakeReviewStorage: ReviewPromptStorage {
    var values: [String: Any] = [:]

    func object(forKey defaultName: String) -> Any? {
        values[defaultName]
    }

    func set(_ value: Any?, forKey defaultName: String) {
        if let value = value {
            values[defaultName] = value
        } else {
            values.removeValue(forKey: defaultName)
        }
    }
}

/// A clock the test moves by hand.
private final class FakeClock {
    var current: Date

    init(_ start: Date) {
        current = start
    }

    func advance(hours: Double) {
        current = current.addingTimeInterval(hours * 3600)
    }

    func advance(minutes: Double) {
        current = current.addingTimeInterval(minutes * 60)
    }
}

final class ReviewPromptPolicyTests: XCTestCase {
    private var storage: FakeReviewStorage!
    private var clock: FakeClock!
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        storage = FakeReviewStorage()
        // 08:00 UTC, so a few hours later is still the same day.
        clock = FakeClock(Date(timeIntervalSince1970: 1_800_000_000))
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        calendar = gregorian
    }

    private func makePolicy(version: String = "1.0.0") -> ReviewPromptPolicy {
        let clock: FakeClock = self.clock
        return ReviewPromptPolicy(storage: storage, appVersion: version, calendar: calendar, now: { clock.current })
    }

    // MARK: First session

    func testNeverAsksDuringFirstSession() {
        let policy = makePolicy()
        policy.startSession()
        XCTAssertFalse(policy.recordExportSuccess())
        XCTAssertFalse(policy.recordExportSuccess())
        XCTAssertFalse(policy.recordExportSuccess())
        XCTAssertEqual(policy.completedExports, 3)
        XCTAssertNil(policy.promptedVersion)
    }

    // MARK: Export count

    func testAsksAfterSecondExportInLaterSession() {
        let policy = makePolicy()
        policy.startSession()
        XCTAssertFalse(policy.recordExportSuccess(), "First session")
        clock.advance(hours: 1)
        policy.startSession()
        XCTAssertTrue(policy.recordExportSuccess(), "Second session with two finished exports")
        XCTAssertEqual(policy.promptedVersion, "1.0.0")
    }

    func testOneExportInSecondSessionIsNotEnoughOnFewDays() {
        let policy = makePolicy()
        policy.startSession()
        clock.advance(hours: 1)
        policy.startSession()
        XCTAssertEqual(policy.activeDays, 1)
        XCTAssertFalse(policy.recordExportSuccess(), "One export, one day of use")
        XCTAssertTrue(policy.recordExportSuccess(), "Second export")
    }

    // MARK: Days of use

    func testAsksOnFirstExportAfterThreeDaysOfUse() {
        let policy = makePolicy()
        policy.startSession()
        clock.advance(hours: 24)
        policy.startSession()
        clock.advance(hours: 24)
        policy.startSession()
        XCTAssertEqual(policy.activeDays, 3)
        XCTAssertEqual(policy.sessionCount, 3)
        XCTAssertTrue(policy.recordExportSuccess())
    }

    func testSeveralLaunchesOnOneDayCountAsOneDay() {
        let policy = makePolicy()
        policy.startSession()
        clock.advance(hours: 1)
        policy.startSession()
        clock.advance(hours: 1)
        policy.startSession()
        XCTAssertEqual(policy.sessionCount, 3)
        XCTAssertEqual(policy.activeDays, 1)
        XCTAssertFalse(policy.recordExportSuccess())
    }

    // MARK: Once per version

    func testNeverAsksTwiceForSameVersion() {
        let policy = makePolicy()
        policy.startSession()
        policy.startSession()
        policy.recordExportSuccess()
        XCTAssertTrue(policy.recordExportSuccess())
        XCTAssertFalse(policy.recordExportSuccess())
        clock.advance(hours: 24 * 30)
        policy.startSession()
        XCTAssertFalse(policy.recordExportSuccess(), "Same version, even a month later")
    }

    func testAsksAgainAfterAppUpdate() {
        let old = makePolicy(version: "1.0.0")
        old.startSession()
        old.startSession()
        old.recordExportSuccess()
        XCTAssertTrue(old.recordExportSuccess())

        let updated = makePolicy(version: "1.1.0")
        clock.advance(hours: 48)
        updated.startSession()
        XCTAssertTrue(updated.recordExportSuccess(), "New version may ask once")
        XCTAssertFalse(updated.recordExportSuccess())
    }

    // MARK: Errors

    func testNeverAsksRightAfterAnError() {
        let policy = makePolicy()
        policy.startSession()
        policy.startSession()
        policy.recordExportSuccess()
        clock.advance(minutes: 1)
        policy.recordExportFailure()
        clock.advance(minutes: 1)
        XCTAssertFalse(policy.recordExportSuccess(), "Success one minute after an error")
        XCTAssertNil(policy.promptedVersion)
    }

    func testAsksAgainOnceErrorCooldownHasPassed() {
        let policy = makePolicy()
        policy.startSession()
        policy.startSession()
        policy.recordExportFailure()
        policy.recordExportSuccess()
        clock.advance(minutes: 11)
        XCTAssertTrue(policy.recordExportSuccess())
    }

    // MARK: Pure check

    func testShouldRequestReviewDoesNotChangeState() {
        let policy = makePolicy()
        policy.startSession()
        policy.startSession()
        policy.recordExportSuccess()
        policy.recordExportSuccess()
        storage.values.removeValue(forKey: ReviewPromptPolicy.Key.promptedVersion)
        let before: Int = storage.values.count
        XCTAssertTrue(policy.shouldRequestReview())
        XCTAssertTrue(policy.shouldRequestReview())
        XCTAssertEqual(storage.values.count, before)
        XCTAssertNil(policy.promptedVersion)
    }

    func testStartsEmpty() {
        let policy = makePolicy()
        XCTAssertEqual(policy.sessionCount, 0)
        XCTAssertEqual(policy.activeDays, 0)
        XCTAssertEqual(policy.completedExports, 0)
        XCTAssertNil(policy.lastErrorAt)
        XCTAssertFalse(policy.shouldRequestReview())
    }

    func testWorksWithRealUserDefaults() {
        let suite: String = "ck.review.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { return XCTFail("No defaults suite") }
        defer { defaults.removePersistentDomain(forName: suite) }
        let clock: FakeClock = self.clock
        let policy = ReviewPromptPolicy(storage: defaults, appVersion: "2.0", calendar: calendar, now: { clock.current })
        policy.startSession()
        policy.startSession()
        XCTAssertEqual(policy.sessionCount, 2)
        XCTAssertFalse(policy.recordExportSuccess())
        XCTAssertTrue(policy.recordExportSuccess())
        XCTAssertEqual(policy.promptedVersion, "2.0")
    }

    // MARK: Center

    @MainActor
    func testCenterIgnoresCancelledAndCountsFailures() {
        let clock: FakeClock = self.clock
        let policy = ReviewPromptPolicy(storage: storage, appVersion: "1.0.0", calendar: calendar, now: { clock.current })
        policy.startSession()
        let center = ReviewPromptCenter(policy: policy)
        XCTAssertEqual(policy.sessionCount, 2, "The center counts its own launch")

        center.exportFinished(.cancelled)
        XCTAssertEqual(policy.completedExports, 0)
        XCTAssertEqual(center.requestCount, 0)

        center.exportFinished(.failed)
        XCTAssertNotNil(policy.lastErrorAt)
        center.exportFinished(.completed)
        center.exportFinished(.completed)
        XCTAssertEqual(center.requestCount, 0, "Too soon after the error")

        clock.advance(minutes: 15)
        center.exportFinished(.completed)
        XCTAssertEqual(center.requestCount, 1)
        center.exportFinished(.completed)
        XCTAssertEqual(center.requestCount, 1, "Once per version")
    }
}
