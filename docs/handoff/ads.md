# Ads module handoff

Owner: ads. Written for the first CI build. Since then CI has built and tested the module many times, but it was never run on a device in development (no Mac); the "Honest gaps" below still apply.

**Two versions.** Build 11 (version 1.0.0, in App Store review) has no StoreKit: the video is the only path and "Export without video" is the fallback whenever no video can play. That is what sections "Export: behaviour and the fallback decision" below describe, kept as the 1.0 record. The unreleased 1.1.0 on `main` adds StoreKit 2 (`Sources/Purchases/`): a consumable 3-export pack and Premium. In 1.1.0 a missing video no longer opens a free export. The free "Export without video" path is only for an **empty product catalog** ("Purchases are not available right now"), never for an unreachable store, and a video that starts late after the 6 s watchdog still counts (`RewardedAdController.lateRewardCount`). See `docs/EXPORT-GATE-IOS.md` for the 1.1.0 rules.

## Files

| File | Purpose |
|---|---|
| `Sources/Ads/AdsSupport.swift` | `AdsConfiguration` (reads `CKBannerAdUnitID` / `CKRewardedAdUnitID`, rejects empty or unresolved `$(...)` values, debug test device list), `AdsPresenter` (top view controller, never crashes), `AdsLog` |
| `Sources/Ads/AdsManager.swift` | `AdsRequestPolicy` (pure: content rating, child tags, readiness, restart rule) and `AdsManager` singleton: UMP consent, then ATT, then `MobileAds.shared.start`; publishes `canRequestAds` and `sdkReady` |
| `Sources/Ads/BannerAdView.swift` | `BannerSlotLogic` (pure), `BannerAdSlot` (one `BannerView` per screen), `BannerAdView`, `CKInlineBanner` |
| `Sources/Ads/RewardedAdController.swift` | Rewarded loader and presenter, `RewardedRetryPolicy`, `RewardedPresentationTiming` (pure) |
| `Sources/Ads/ExportFallbackPolicy.swift` | `RewardedUnavailableReason`, `ExportVideoOutcome`, `ExportFlowDecision`, `ExportFallbackPolicy` (pure export fallback rules) |
| `Sources/Ads/ExportGate.swift` | `ExportGateLogic` (pure rules) and `ExportGate` (persisted, observable) |
| `Sources/Ads/ExportFileSupport.swift` | `ExportFileName` sanitiser, `ExportFileWriter` temp PDF writer |
| `Sources/Ads/ExportActionRunner.swift` | Share sheet, Save to Files, Print, each reporting completed / cancelled / failed |
| `Sources/Ads/ExportFlowSheet.swift` | The export sheet |
| `Sources/Resources/PrivacyInfo.xcprivacy` | App privacy manifest (no tracking domains, see below) |
| `Sources/Resources/Info.plist` | `SKAdNetworkItems` (50 ids) and the ad id keys |
| `Tests/AdsExportGateLogicTests.swift`, `Tests/AdsHelpersTests.swift`, `Tests/AdsFallbackAndBannerTests.swift` | Unit tests |

No ad ids in Swift. (Build 11 has no StoreKit; 1.1.0 has StoreKit in `Sources/Purchases/`, outside this module.)

## API implemented (and deviations from the contract)

- `AdsManager.shared`, `canRequestAds`, `start() async`, `presentPrivacyOptions()`, `privacyOptionsRequired`: as contract. Extra: `sdkReady` (published, true after `MobileAds.shared.start` completes), `adsReady` (`canRequestAds && sdkReady`), `consentRevision`, `resetConsentForTesting()` (DEBUG only). `start()` is safe to call twice.
- `BannerAdView()`: as contract (owns its own slot). Extra: `BannerAdView(slot:spacing:showsLabel:)` and `CKInlineBanner()` / `CKInlineBanner(slot:)`.
- `RewardedAdController`: `State`, `@Published var state`, `load()`, `present() async -> Bool` as contract. Deviations: `@MainActor`, `NSObject` subclass, `init(preload: Bool = true)`. Extra: `unavailableReason`, `preload()`, `cancelRetries()`, `expireIfStale()`, `lastPresentationFailed`.
- `ExportGate`: as contract plus `forget(documentID:)`.
- `ExportFlowSheet(documentID:fileName:renderedProvider:)`: as contract. Needs `ExportGate` as an environment object. Title is now "Export as PDF" (it is used for resumes and cover letters).

## Export: behaviour and the fallback decision

1. First screen: "Watch one short video to export this document once. After the video, the export stays unlocked for 24 hours, so you can finish later." Primary button **Watch an ad to export**, secondary **Not now**. The video is the primary path. The rewarded ad is preloaded in the background when the sheet opens; it never plays without the tap.
2. After the tap: spinner with **Cancel** (interactive dismissal off). The sheet waits up to 20 s and retries one plain load failure.
3. Earned reward -> grant -> Share / Save to Files / Print.
4. Video closed early -> "Video not finished" with **Watch again** and **Not now**. Still locked.
5. **No video could be provided** (not configured, consent does not allow ads, load failed twice, 20 s timeout, failed to present or never started) -> "No video right now" with a plain reason ending "so this export is free.", primary **Export without video** (calls `gate.grant` and continues to the destination), then **Try the video again** (hidden when ids are missing), **Review privacy choices** (only for consent and only when Google says the form is required), **Not now**. Copy never calls it a reward.

**Fallback policy: unlimited, no rate limit.** Any limit (for example once per document per 24 h) would bring back a dead end for an App Reviewer who tests the same document twice on a device with no fill or after declining consent, and guideline 2.1 rejections for "export does not work" are the bigger risk. Abuse is limited by the fact that the free path appears only after the person asked for a video and none could be shown; going offline to skip a video is possible and accepted. If revenue data later shows abuse, a limit can be added in `ExportFallbackPolicy.decision(for:)` without UI changes, but keep the always-exportable guarantee for App Review.

Grant semantics are unchanged: one grant per document, one export, valid 24 hours (now disclosed in the sheet), no stacking, consumed only after the system reports a finished share, save or print. The free path uses the same grant.

## Rewarded controller fixes

- B1: the ad on screen is held strongly in `presentingAd` until a dismiss or failure callback, so the callbacks always arrive. Callbacks for any other ad are ignored.
- B2: the reward handler can arrive after `adDidDismissFullScreenContent`. Finishing waits one main-queue hop, then up to 250 ms for the reward flag.
- Cancellation: `present()` uses `withTaskCancellationHandler`; a cancelled caller is resumed with `false`. A 6 s watchdog resolves the caller with "could not present" if the SDK never reports the video starting. The continuation is resumed exactly once.
- B3: loads wait for `sdkReady`; a load requested before the SDK finished starting continues automatically.

## Banner fixes and placement policy

- B3: banners render only when `adsReady` (consent, then ATT, then SDK start finished).
- B4: one `BannerView` per screen in `BannerAdSlot`, kept by the screen in a `@StateObject` (My Resumes, Cover Letters, Templates). Rebuilt or recycled rows reuse it. Retries are cancelled while the banner is off screen and resumed when it returns.
- B5: a failure after an ad has loaded is a refresh failure and is ignored (the SDK keeps the old ad).
- B6: if the first start ran without a window or without network and ads are still not allowed, `start()` runs again when the app becomes active (at most every 30 s).
- B7: a width change resets the slot (collapses) and sends one new request.
- Size: inline adaptive (`inlineAdaptiveBanner(width:maxHeight: 150)`) for every placement, since all placements are now at the end of scrolling content. There is no anchored placement left. If one is ever added, use `largeAnchoredAdaptiveBanner(width:)` on an opaque background with spacing from the tab bar.
- Placement: end of content only, never on empty, no-results or error states, never overlapping list content, never flush against the iOS 26 floating tab bar. `CKInlineBanner` adds 24 pt above, 16 pt below and a small "Advertisement" label, only while an ad is showing.
  - Home: end of the dashboard.
  - Templates: after the last template, hidden when there are no results.
  - My Resumes: last list row / end of the grid. The empty state has none.
  - Cover Letters: last list row (no more bottom inset). Empty and no-results states have none.
  - **Profile (worker B, please adopt):** replace the `bannerSection` contents in `ProfileView.swift` with `CKInlineBanner(slot: bannerSlot)` and add `@StateObject private var bannerSlot = BannerAdSlot()`. Keep `.listRowBackground(Color.clear)` and `.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))`. The wrapper gives the required 16 pt or more separation from the support rows.

## Request configuration

- `maxAdContentRating = .general` (matches the 4+ age rating answers, with Advertising: Yes).
- `tagForChildDirectedTreatment` and `tagForUnderAgeOfConsent` are not set: the app is not child-directed.
- Test device ids only in DEBUG.

## Privacy manifest

`NSPrivacyTrackingDomains` was removed. iOS blocks declared tracking domains for people who deny ATT, and the old entries came from memory, not from the SDK. `NSPrivacyTracking` is `false` on purpose: App Store Connect (ITMS-91064) rejects `true` without tracking domains, and domains are deliberately not declared. **This does not mean the app never tracks.** AdMob can use the advertising identifier for tracking after the person allows it in the ATT prompt, so the App Store Connect App Privacy answer must be "Yes, tracking" for Device ID and Advertising Data. The manifest flag and that label are separate declarations. Do not flip the flag. The reasoning is written out in `docs/store/app-privacy.md`. The ATT prompt and consent flow are unaffected. Collected data types match `docs/store/app-privacy.md` exactly (Device ID: linked, tracking, Third-Party Advertising and Analytics; Advertising Data: linked, tracking; Product Interaction: linked, not tracking; Coarse Location: not linked; Performance Data: linked; Crash Data: not linked). After the first archive, check Xcode's privacy report.

## AdMob console steps

1. Production ids are in `Config/Release.xcconfig` (publisher `pub-8621573128492952`). Debug keeps Google's test ids.
2. Privacy & messaging: publish the GDPR message (and the US states message if wanted) for this iOS app, so the UMP form appears.
3. Blocking controls: block sensitive categories (gambling, dating, politics, weight loss and similar).
4. `app-ads.txt`: `google.com, pub-8621573128492952, DIRECT, f08c47fec0942fa0` at the root of the Marketing URL host. A GitHub project page root is not controllable; use `https://www.ecomswiftllc.com` as the Marketing URL if the owner controls it, else a user-site repo `EcomswiftLLC/ecomswiftllc.github.io`.
5. **TestFlight uses production ids.** Register every tester iPhone and iPad as an AdMob test device before installing a TestFlight build. Never tap production ads. One invalid-traffic flag can affect the whole shared account.
6. After launch, link the app to its App Store listing in AdMob.

## Compile risks to watch in CI

- `inlineAdaptiveBanner(width:maxHeight:)` (v12 Swift name of `GADInlineAdaptiveBannerAdSizeWithWidthAndMaxHeight`). If missing, try `currentOrientationInlineAdaptiveBanner(width:)`.
- `configuration.maxAdContentRating = .general` relies on implicit member lookup through the optional `GADMaxAdContentRating?`. If it fails, write `GADMaxAdContentRating.general` (or `MaxAdContentRating.general` in v12).
- `MobileAds.shared.start(completionHandler:)` closure parameter type (`InitializationStatus`).
- `FullScreenContentDelegate` / `BannerViewDelegate` conformance from `@MainActor` classes. If CI reports isolation errors, mark the delegate methods `nonisolated` and hop with `Task { @MainActor in ... }`.
- `withTaskCancellationHandler { } onCancel: { }` inside a `@MainActor` method (Swift 5.10).
- `adWillPresentFullScreenContent(_:)` is optional in the protocol; if the SDK never calls it, the 6 s watchdog would answer "could not present" while a video plays (the late dismiss still tidies up). Watch for this on a device.

## Honest gaps (not compiled, not run)

- Never compiled. Never seen on a device or simulator. Check on a small iPhone with the largest Dynamic Type size, on iPad (share popover anchoring), in dark mode, and with VoiceOver and Reduce Motion on.
- Not tested: the real consent form, the ATT prompt, offline start, consent withdrawal while a video is loading, reward and dismiss callback ordering, inline banner heights.
- `HowExportsWorkView` (Profile) was rewritten for 1.1.0 and now describes the video, the pack, Premium and Restore purchases, and switches to the "purchases are not available" wording when the catalog is empty. The old suggested 1.0 text (that the export sheet lets you export without a video if none can play) is true only for build 11.
- The live pages in `website/careerkit/` match build 11. The 1.1.0 wording is built separately with `CAREERKIT_EDITION=1.1 python website/build_site.py` into `website/draft-1.1/careerkit/` and published only when 1.1.0 is released (with `CAREERKIT_SUPPORT_EMAIL` set).
- Unit tests cover the pure logic (gate rules and persistence, fallback policy, banner slot rules, request policy, presentation timing, file names, id normaliser, retry policy). The SDK-facing code has no unit tests.
