import XCTest
@testable import CareerKit

/// A video that cannot be provided never unlocks an export. The person is pointed to the other ways to export.
final class AdsExportFallbackPolicyTests: XCTestCase {
    private let allReasons: [RewardedUnavailableReason] = [
        .notConfigured, .noConsent, .loadFailed, .timedOut, .couldNotPresent
    ]

    func testEarnedUnlocks() {
        XCTAssertEqual(ExportFallbackPolicy.decision(for: .earned), .unlock)
    }

    func testClosedEarlyOffersWatchAgainNotFreeExport() {
        XCTAssertEqual(ExportFallbackPolicy.decision(for: .closedEarly), .offerWatchAgain)
    }

    func testEveryUnavailableReasonReportsNoVideoAndNeverUnlocks() {
        for reason in allReasons {
            let decision = ExportFallbackPolicy.decision(for: .unavailable(reason))
            XCTAssertEqual(decision, .videoUnavailable(reason))
            XCTAssertNotEqual(decision, .unlock, "No video (\(reason)) must never unlock an export")
        }
    }

    func testOnlyAnEarnedRewardUnlocks() {
        XCTAssertEqual(ExportFallbackPolicy.decision(for: .earned), .unlock)
        XCTAssertNotEqual(ExportFallbackPolicy.decision(for: .closedEarly), .unlock)
        for reason in allReasons {
            XCTAssertNotEqual(ExportFallbackPolicy.decision(for: .unavailable(reason)), .unlock)
        }
    }

    func testOnlyPlainLoadFailuresAreRetriedOnce() {
        XCTAssertEqual(ExportFallbackPolicy.loadAttemptsBeforeFallback, 2)
        XCTAssertTrue(ExportFallbackPolicy.shouldRetryLoad(after: .loadFailed, attemptsSoFar: 1))
        XCTAssertFalse(ExportFallbackPolicy.shouldRetryLoad(after: .loadFailed, attemptsSoFar: 2))
        for reason in allReasons where reason != .loadFailed {
            XCTAssertFalse(ExportFallbackPolicy.shouldRetryLoad(after: reason, attemptsSoFar: 1))
        }
    }

    func testWaitIsBounded() {
        XCTAssertGreaterThan(ExportFallbackPolicy.adWaitTimeout, 0)
        XCTAssertLessThanOrEqual(ExportFallbackPolicy.adWaitTimeout, 30)
    }

    func testPrivacyOptionsOnlyForConsentWhenRequired() {
        XCTAssertTrue(ExportFallbackPolicy.offersPrivacyOptions(for: .noConsent, privacyOptionsRequired: true))
        XCTAssertFalse(ExportFallbackPolicy.offersPrivacyOptions(for: .noConsent, privacyOptionsRequired: false))
        XCTAssertFalse(ExportFallbackPolicy.offersPrivacyOptions(for: .loadFailed, privacyOptionsRequired: true))
    }

    func testMessagesArePlainAndNeverCallItAReward() {
        for reason in allReasons {
            let text = reason.exportMessage.lowercased()
            XCTAssertFalse(text.contains("this export is free"), "\(reason): \(text)")
            XCTAssertFalse(text.isEmpty)
            XCTAssertFalse(text.contains("reward"), "\(reason): \(text)")
            XCTAssertFalse(text.contains("internet connection"), "Do not guess at the cause: \(text)")
            XCTAssertFalse(text.contains("\u{2014}"), "No em dashes")
        }
    }
}

/// The free "Export without video" wording and the late reward rule.
final class AdsFreeExportAndLateRewardTests: XCTestCase {
    func testFreeExportMessagesNameTheReasonAndSayTheExportIsFree() {
        let reasons: [RewardedUnavailableReason] = [.notConfigured, .noConsent, .loadFailed, .timedOut, .couldNotPresent]
        for reason in reasons {
            let text = reason.freeExportMessage
            XCTAssertTrue(text.contains("so this export is free"), "\(reason): \(text)")
            XCTAssertNotEqual(text, reason.exportMessage)
            XCTAssertFalse(text.lowercased().contains("reward"))
        }
    }

    func testARewardEarnedAfterTheCallerWasAnsweredStillCounts() {
        XCTAssertTrue(RewardedPresentationTiming.isLateReward(earned: true, callerAlreadyAnswered: true))
        XCTAssertFalse(RewardedPresentationTiming.isLateReward(earned: false, callerAlreadyAnswered: true), "a video closed early earns nothing")
        XCTAssertFalse(RewardedPresentationTiming.isLateReward(earned: true, callerAlreadyAnswered: false), "the waiting caller gets it directly")
    }
}

/// A video grant: one grant, one export, 24 hours (as the sheet discloses).
final class AdsExportGateFallbackTests: XCTestCase {
    private let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)

    func testDisclosedLifetimeIs24Hours() {
        XCTAssertEqual(ExportGateLogic.lifetime, 24 * 60 * 60)
    }

    func testVideoGrantIsOneExportOnly() {
        var logic = ExportGateLogic()
        let doc = UUID()
        logic.grant(for: doc, now: t0)   // completed rewarded video
        XCTAssertTrue(logic.hasGrant(for: doc, now: t0.addingTimeInterval(60)))
        XCTAssertTrue(logic.consume(for: doc, now: t0.addingTimeInterval(120)))
        XCTAssertFalse(logic.hasGrant(for: doc, now: t0.addingTimeInterval(121)))
    }

    func testCancelledShareKeepsGrantUntilExpiry() {
        var logic = ExportGateLogic()
        let doc = UUID()
        logic.grant(for: doc, now: t0)
        // No consume call for a cancelled share.
        XCTAssertTrue(logic.hasGrant(for: doc, now: t0.addingTimeInterval(ExportGateLogic.lifetime - 1)))
        XCTAssertFalse(logic.hasGrant(for: doc, now: t0.addingTimeInterval(ExportGateLogic.lifetime)))
    }
}

final class AdsRequestPolicyTests: XCTestCase {
    func testContentRatingIsGeneralForA4PlusApp() {
        XCTAssertEqual(AdsRequestPolicy.maxContentRating, .general)
        XCTAssertEqual(AdsRequestPolicy.maxContentRating.rawValue, "G")
    }

    func testChildDirectedTagsStayUnset() {
        XCTAssertNil(AdsRequestPolicy.tagForChildDirectedTreatment)
        XCTAssertNil(AdsRequestPolicy.tagForUnderAgeOfConsent)
    }

    func testAdsNeedConsentAndStartedSDK() {
        XCTAssertFalse(AdsRequestPolicy.adsReady(canRequestAds: false, sdkReady: false))
        XCTAssertFalse(AdsRequestPolicy.adsReady(canRequestAds: true, sdkReady: false))
        XCTAssertFalse(AdsRequestPolicy.adsReady(canRequestAds: false, sdkReady: true))
        XCTAssertTrue(AdsRequestPolicy.adsReady(canRequestAds: true, sdkReady: true))
    }

    func testRestartOnActiveRules() {
        XCTAssertFalse(AdsRequestPolicy.shouldRestartOnActive(startAttempted: false, canRequestAds: false, blockedByEnvironment: true, secondsSinceLastStart: nil),
                       "Never start before the app asked for it (onboarding)")
        XCTAssertFalse(AdsRequestPolicy.shouldRestartOnActive(startAttempted: true, canRequestAds: true, blockedByEnvironment: true, secondsSinceLastStart: 100))
        XCTAssertFalse(AdsRequestPolicy.shouldRestartOnActive(startAttempted: true, canRequestAds: false, blockedByEnvironment: false, secondsSinceLastStart: 100),
                       "A real decline is not retried by itself")
        XCTAssertTrue(AdsRequestPolicy.shouldRestartOnActive(startAttempted: true, canRequestAds: false, blockedByEnvironment: true, secondsSinceLastStart: AdsRequestPolicy.restartThrottle))
        XCTAssertFalse(AdsRequestPolicy.shouldRestartOnActive(startAttempted: true, canRequestAds: false, blockedByEnvironment: true, secondsSinceLastStart: 1))
    }
}

final class AdsRewardedTimingTests: XCTestCase {
    func testEarnedOnlyWithRewardAndNoFailureOrCancel() {
        XCTAssertTrue(RewardedPresentationTiming.earned(rewardEarned: true, failedToPresent: false, cancelled: false))
        XCTAssertFalse(RewardedPresentationTiming.earned(rewardEarned: false, failedToPresent: false, cancelled: false))
        XCTAssertFalse(RewardedPresentationTiming.earned(rewardEarned: true, failedToPresent: true, cancelled: false))
        XCTAssertFalse(RewardedPresentationTiming.earned(rewardEarned: true, failedToPresent: false, cancelled: true))
    }

    func testGraceAndWatchdogAreShortAndOrdered() {
        XCTAssertLessThanOrEqual(RewardedPresentationTiming.rewardGrace, 0.5)
        XCTAssertGreaterThan(RewardedPresentationTiming.rewardGrace, 0)
        XCTAssertLessThan(RewardedPresentationTiming.rewardPollStep, RewardedPresentationTiming.rewardGrace)
        XCTAssertLessThanOrEqual(RewardedPresentationTiming.presentWatchdog, 10)
    }
}

final class AdsBannerSlotLogicTests: XCTestCase {
    func testFirstWidthRequestsALoad() {
        var logic = BannerSlotLogic()
        XCTAssertTrue(logic.widthChanged(to: 374.6))
        XCTAssertEqual(logic.width, 374)
        XCTAssertEqual(logic.status, .loading)
    }

    func testTinyOrZeroWidthChangesDoNotReload() {
        var logic = BannerSlotLogic()
        XCTAssertFalse(logic.widthChanged(to: 0))
        XCTAssertTrue(logic.widthChanged(to: 375))
        XCTAssertFalse(logic.widthChanged(to: 375.4))
    }

    func testWidthChangeResetsStatus() {
        var logic = BannerSlotLogic()
        _ = logic.widthChanged(to: 375)
        logic.didReceiveAd()
        XCTAssertTrue(logic.isShowing)
        XCTAssertTrue(logic.widthChanged(to: 812))
        XCTAssertFalse(logic.isShowing, "A new width collapses the slot until the new ad arrives")
        XCTAssertFalse(logic.hasLoadedAd)
    }

    func testRefreshFailureAfterLoadIsIgnored() {
        var logic = BannerSlotLogic()
        _ = logic.widthChanged(to: 375)
        logic.didReceiveAd()
        XCTAssertEqual(logic.didFail(), .ignore)
        XCTAssertTrue(logic.isShowing)
    }

    func testRetriesAreCapped() {
        var logic = BannerSlotLogic()
        _ = logic.widthChanged(to: 375)
        for _ in 0..<BannerSlotLogic.maxRetries {
            XCTAssertEqual(logic.didFail(), .retry(after: BannerSlotLogic.retryDelay))
        }
        XCTAssertEqual(logic.didFail(), .giveUp)
        XCTAssertEqual(logic.status, .failed)
    }

    func testResetClearsEverything() {
        var logic = BannerSlotLogic()
        _ = logic.widthChanged(to: 375)
        logic.didReceiveAd()
        logic.reset()
        XCTAssertEqual(logic, BannerSlotLogic())
    }

    func testInlineSpacingKeepsAtLeast16Points() {
        XCTAssertGreaterThanOrEqual(BannerSizing.inlineTopSpacing, 16)
        XCTAssertGreaterThanOrEqual(BannerSizing.inlineBottomSpacing, 16)
    }
}
