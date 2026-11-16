# Ads module handoff

Owner: ads. Nothing here was compiled or run (no Mac). macOS CI is the first compile. Expect to fix small typos or SDK signature drift on the first run.

## Files

| File | Purpose |
|---|---|
| `Sources/Ads/AdsSupport.swift` | `AdsConfiguration` (reads `CKBannerAdUnitID` / `CKRewardedAdUnitID`, rejects empty or unresolved `$(...)` values, debug test device list), `AdsPresenter` (top view controller, never crashes), `AdsLog` |
| `Sources/Ads/AdsManager.swift` | `AdsManager` singleton: UMP consent, then ATT, then `MobileAds.shared.start` |
| `Sources/Ads/BannerAdView.swift` | Adaptive banner view |
| `Sources/Ads/RewardedAdController.swift` | Rewarded loader and presenter, `RewardedRetryPolicy` |
| `Sources/Ads/ExportGate.swift` | `ExportGateLogic` (pure rules) and `ExportGate` (persisted, observable) |
| `Sources/Ads/ExportFileSupport.swift` | `ExportFileName` sanitiser, `ExportFileWriter` temp PDF writer |
| `Sources/Ads/ExportActionRunner.swift` | Share sheet, Save to Files, Print, each reporting completed / cancelled / failed |
| `Sources/Ads/ExportFlowSheet.swift` | The export sheet |
| `Sources/Resources/PrivacyInfo.xcprivacy` | App privacy manifest |
| `Sources/Resources/Info.plist` | `SKAdNetworkItems` only (50 ids) |
| `Tests/AdsExportGateLogicTests.swift`, `Tests/AdsHelpersTests.swift` | Unit tests |

No StoreKit anywhere. No ids in Swift.

## API implemented (and deviations from the contract)

- `AdsManager.shared`, `canRequestAds`, `start() async`, `presentPrivacyOptions()`, `privacyOptionsRequired`: as contract. Extra: `consentRevision` (published, refreshes views), `resetConsentForTesting()` (DEBUG only). `start()` is safe to call twice.
- `BannerAdView()`: as contract. It is `@MainActor`.
- `RewardedAdController`: `State`, `@Published var state`, `load()`, `present() async -> Bool` as contract. Deviations: it is `@MainActor` and an `NSObject` subclass (needed for the SDK delegate); `init(preload: Bool = true)`. Extra: `expireIfStale()`, `lastPresentationFailed`.
  - `present()` returns true only if the SDK's `userDidEarnRewardHandler` fired for that showing. It waits for the ad to be dismissed before returning, so the sheet does not change under a playing video. The continuation is resumed exactly once (dismiss or failure to present).
- `ExportGate`: `hasGrant(for:)`, `grant(for:)`, `consume(for:)` as contract. Extra: `forget(documentID:)` (appui can call it when a document is deleted). `init` has defaults, so `ExportGate()` works.
- `ExportFlowSheet(documentID:fileName:renderedProvider:)`: as contract. It reads `ExportGate` from the environment (`@EnvironmentObject`), so the root must inject it, as the contract already says. It uses `AdsManager.shared` directly.

### Behaviour worth knowing

- Grants: one per document id, valid 24 hours, one export. A second grant for the same document while one is valid is ignored (no stacking, no extension). A grant dated in the future (device clock moved back more than 5 minutes) is invalid.
- A grant is created only in `ExportFlowSheet` after `present()` returned true. It is consumed only after the share sheet, Files exporter or print dialog reports `completed == true`. A cancelled share keeps the grant, and reopening the sheet goes straight to the destination step.
- The rewarded ad never starts by itself. The person taps "Watch an Ad to Export Free". After that tap the sheet shows a spinner with Cancel and plays the video as soon as it is loaded, unless they cancelled. Interactive dismissal is disabled during that wait.
- Failure states use plain messages and "Try again". There is no payment fallback.
- Rendering runs in a detached task after the reward (or immediately when a grant already exists). The PDF is written to `tmp/CareerKitExport-<uuid>/<sanitised name>.pdf`. The folder is removed when the sheet's state object is released.
- Banner: `currentOrientationAnchoredAdaptiveBanner(width:)` is marked deprecated in v12 in favour of `largeAnchoredAdaptiveBanner(width:)`. I kept the contract name because it is certain to exist; it only gives a deprecation warning. Switch later if you want the larger anchored size.
- Banner retries: up to 3 quiet retries, 60 seconds apart, then stops until the view is rebuilt.
- Rewarded retries: up to 4 automatic retries at 4, 8, 16, 32 seconds, then waits for the user to tap "Try again". A loaded ad older than 55 minutes is discarded.

## Known product gap (needs an owner decision)

Export requires a rewarded video, and a video needs ad consent. A person in a region where Google's consent form applies who refuses consent, or whose consent state does not allow ads, cannot export at all. The sheet explains this in plain words and offers "Review privacy choices" when Google says that form is required. I did not add any bypass, because the contract says no export without a completed reward. Options if you want to change that: allow an export when `ConsentInformation` says ads cannot be requested (policy risk: none for AdMob, but it is a revenue and product decision), or show limited/non-personalised ads where Google's consent mode allows them. Please decide before App Store review, since Apple may test with ads unavailable.

## App Privacy questionnaire (App Store Connect) for this app

The app has no accounts, no analytics SDK of its own, and documents stay on device. Only the Google Mobile Ads SDK (AdMob) and the UMP SDK collect data.

Does this app collect data? **Yes.**

Data types to tick:

| Data type | Linked to the user | Used to track | Purposes |
|---|---|---|---|
| Identifiers > Device ID | Yes | Yes | Third-Party Advertising |
| Usage Data > Advertising Data | Yes | Yes | Third-Party Advertising |
| Usage Data > Product Interaction | Yes | No | Third-Party Advertising |
| Location > Coarse Location | No | No | Third-Party Advertising |
| Diagnostics > Performance Data | Yes | No | Third-Party Advertising, Analytics |
| Diagnostics > Crash Data | No | No | Analytics |

Everything else: **not collected** (Contact Info, Health, Financial, Contacts, User Content, Browsing History, Search History, Purchases, Sensitive Info, Other Data). Resume text, photos and cover letters never leave the device, so User Content is not collected.

"Do you or your third-party partners use data for tracking?" **Yes** (AdMob, only if the person allows it in the ATT prompt).

Tracking domains: declared in the manifest (see gaps). ATT text is already in Info.plist (`NSUserTrackingUsageDescription`).

These answers follow Google's published AdMob disclosure table (device id, advertising data, product interaction, coarse location, performance data, crash data). Google's page does not say "linked" for every row. I marked rows linked when Google described them as user associated or when an advertising identifier is involved, which is the conservative choice. Re-check against Google's current "App Store data disclosure" page when you submit.

## AdMob console steps (do these before App Store submission)

1. Sign in at admob.google.com with the account that owns the other apps. Because one invalid-traffic flag can affect the whole shared account, do not test with real ids on a real device (use test devices) and never tap your own ads.
2. Apps > Add app > **iOS**. Answer "Is the app listed on a supported app store?" with No until it is live; name it "CareerKit". Copy the **App ID** (`ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`).
3. Ad units > Add ad unit > **Banner**. Name "CareerKit Banner Browse". Copy the unit id (`ca-app-pub-.../...`). Leave the refresh at the default.
4. Ad units > Add ad unit > **Rewarded**. Name "CareerKit Rewarded Export". Reward item: "Export", amount 1. Leave "Server-side verification" off. Copy the unit id.
5. Put the three real ids into `Config/Release.xcconfig` (`ADMOB_APP_ID`, `ADMOB_BANNER_UNIT_ID`, `ADMOB_REWARDED_UNIT_ID`). Keep `Config/Debug.xcconfig` on Google's test ids.
6. Privacy & messaging > **European regulations**: create and publish a GDPR message for the iOS app, so the UMP form appears. Also create the **Privacy options** entry point message if you want the Settings row to work. Add the US states message if you serve US users in states that require it.
7. Privacy & messaging > **IDFA explainer**: optional. If enabled, it appears before the system ATT prompt.
8. Account > Settings > Account information: confirm the payment profile and the app-ads.txt if you have a developer website (iOS app-ads.txt is read from the developer URL on the App Store listing).
9. After the app is live, link it to its App Store listing in AdMob (Apps > App settings).

## Policy hygiene built in

- Banner only where the owner of each browse screen places `BannerAdView`. It must be a row of its own, never beside a primary button, never on editor, preview or export screens (appui and editor owners: please keep to this).
- No interstitials, no app-open ads. No text that asks for taps. The accessibility label is "Advertisement".
- The rewarded video is always the person's choice, started by their own tap, with a Cancel while it loads.

## Honest gaps (not compiled, not run)

- **Never compiled.** SDK names were checked against Google's docs (v12 `BannerView`, `Request`, `RewardedAd.load(with:request:)` async, `FullScreenContentDelegate` method names, `present(from:userDidEarnRewardHandler:)`, `MobileAds.shared.start(completionHandler:)`, UMP v3 `requestConsentInfoUpdate(with:)`, `ConsentForm.loadAndPresentIfRequired(from:)`, `presentPrivacyOptionsForm(from:)`, `privacyOptionsRequirementStatus`). The exact parameter nullability and `@MainActor` annotations on SDK types were not checked. If CI reports an isolation error on a delegate method, mark it `nonisolated` and hop with `Task { @MainActor in }`.
- **Tracking domains are unverified.** I could not fetch a Google page that lists them. The manifest declares `googleads.g.doubleclick.net`, `pagead2.googlesyndication.com` and `googleadservices.com` from general knowledge. Declared tracking domains are blocked for people who deny ATT. The Google SDK ships its own privacy manifest, so these may duplicate it. After the first archive, open Xcode's Privacy Report (Product > Archive > Generate Privacy Report), compare the merged domains with the SDK's, and delete any domain here that the SDK does not itself declare. If App Store Connect rejects the manifest, set `NSPrivacyTracking` to match what the merged report shows.
- Required-reason APIs declared: UserDefaults `CA92.1` (ExportGate and appui settings) and file timestamp `C617.1` (the Persistence module reads document dates). Neither was verified against other owners' code; boot time and disk space are not declared because Ads code does not use them. If engine/appui use other required-reason APIs, add them.
- SKAdNetwork: the full list of 50 ids from Google's quick-start page (fetched 2026-11-16, identical on the `3p-skadnetworks` page). Google updates it from time to time. Third-party mediation partners would need their own ids; there is no mediation here.
- UI was never seen on a device or simulator. Check on a small iPhone with the largest Dynamic Type size, on iPad (share popover anchoring), in dark mode, and with VoiceOver and Reduce Motion on.
- Not tested: the real consent form, the ATT prompt, offline start, consent withdrawal while a video is loading, rewarded callback ordering. Test with Google test ids and a registered test device (`AdsConfiguration.debugTestDeviceIdentifiers`, DEBUG only). To force the EEA form, uncomment `debug.geography = .EEA` in `AdsManager.consentRequestParameters()`.
- `BannerAdView` measures its width with a background `GeometryReader`. If a parent gives it no width (for example inside a horizontal scroll view) it stays collapsed.
- Unit tests cover the pure logic (gate rules, persistence round trip through UserDefaults, file name sanitiser, id normaliser, retry policy). The SDK-facing code has no unit tests.
