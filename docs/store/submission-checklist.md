# Submission checklist: Resume & CV Maker: CareerKit

**This checklist is for version 1.1.0 (export packs and Premium).** Version 1.0.0 (build 11) is in review with no in-app purchases; its checklist is kept unchanged in `v1.0-in-review/submission-checklist.md`. Do not start the 1.1.0 steps in App Store Connect until 1.0.0 is decided.

Legend: **Done** = finished in this repository. **Owner** = needs the account holder (logins, payments, legal identity). **Mac/CI** = needs macOS (Xcode) or the GitHub Actions macOS runner. **Open** = decision or check still to be made.

Banking and tax forms in App Store Connect **are required for 1.1.0**. The app now sells two in-app purchases, so the Paid Applications Agreement must be accepted and the bank account and tax forms must be complete (Business > Agreements, Tax, and Banking) before the products can be tested with real App Store data or released. This was not needed for 1.0.0. (AdMob has its own, separate payment profile, see section 3.)

## 1. Apple Developer account and app record

| # | Step | Status |
|---|---|---|
| 1.1 | Active Apple Developer Program membership for the team in `project.yml` (`DEVELOPMENT_TEAM: N84NGN3KSH`). Confirm the team id is the right one for Ecom Swift LLC. | Owner |
| 1.2 | Register explicit App ID `com.ecomswift.careerkit` (Certificates, Identifiers & Profiles). The In-App Purchase capability is on by default for every App ID; no push or iCloud is needed. | Owner |
| 1.3 | Create the app in App Store Connect: name `Resume & CV Maker: CareerKit`, English (U.S.), bundle id above, SKU `careerkit-ios`, full access. If the name is taken use the fallbacks in `metadata.md`. | Owner |
| 1.4 | EU Digital Services Act trader status: as a business, Ecom Swift LLC declares itself a trader in App Store Connect (Business > Compliance). Address, phone and email are shown publicly in the EU. If the owner does not want that, remove EU countries from Availability. | Owner |
| 1.5 | Keep the price at Free and set availability. | Owner |
| 1.6 | Accept the Paid Applications Agreement and complete banking and tax in Business > Agreements, Tax, and Banking. Answer the tax questions as the legal entity (US LLC); use the forms App Store Connect shows and do not guess. | Owner |
| 1.7 | Create the two in-app purchases (Monetization > In-App Purchases): `export_pack_3` (Consumable, USD 0.99, reference name "Export Pack 3", display name "3 Exports") and `premium_unlimited` (Non-Consumable, price chosen by the owner, display name "Premium"). Add a display name and description for every store language (en, es, fr, de, zh-Hans), a review screenshot of the export sheet with prices (the `70-export-paywall.png` screenshot from the CI screenshots artifact) and review notes. Product ids must match `Sources/Purchases/ExportEntitlementLogic.swift` exactly. Details and suggested texts are in `../EXPORT-GATE-IOS.md`. | Owner |
| 1.8 | Attach both products to the 1.1.0 version on the version page (In-App Purchases and Subscriptions section) before submitting that version. The first purchases must be submitted together with a new app version. | Owner |
| 1.9 | Decide the Premium price and whether "Export backup" in Profile should also use an export. Both are product decisions; the code supports either. | Owner |

## 2. Build and signing

| # | Step | Status |
|---|---|---|
| 2.1 | Project generates from `project.yml` with XcodeGen. Assets catalog, AppIcon, AccentColor and LaunchBackground exist. | Done |
| 2.2 | Compiles and tests on macOS in CI (`.github/workflows/ios.yml`, Xcode 26): unit tests, Release build check with the production AdMob ids, UI screenshots in 5 languages, iPad landscape check. There is no Mac here, so CI is the only compiler. Confirm the latest `ios.yml` run on `main` is green before building 1.1.0. | Done when CI is green |
| 2.2a | StoreKit was never run against the App Store or the sandbox during development. `Config/StoreKit/Configuration.storekit` is a local file for Xcode only and is not part of any target. Test the purchase flow on a real device with a sandbox account (section 6) before release. | Open, needs a device |
| 2.3 | `Config/Release.xcconfig` already holds the three production AdMob ids (app "Resume & CV Maker: CareerKit", created 2026-11-16). `Config/Debug.xcconfig` keeps Google's test ids. Before archiving, confirm the archive uses the Release configuration. | Done, confirm on archive |
| 2.4 | Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml` when needed (now 1.1.0; the build number is set by the release workflow, so a new upload is always higher than build 11). | Done |
| 2.5 | Archive in Xcode (Product > Archive, Any iOS Device) with automatic signing. Upload through the Organizer, or export and upload with Transporter. | Mac |
| 2.6 | Confirm the icon shows (1024 px, no alpha) and the build passes App Store Connect processing. | Mac |
| 2.7 | Export compliance: `ITSAppUsesNonExemptEncryption` is already `false` in Info.plist, so the question is skipped for each build. The app only uses the standard HTTPS stack of iOS (through the ad SDK). If App Store Connect still asks: "Does your app use encryption? Yes, only exempt standard encryption", no French declaration needed. | Done, confirm in ASC |

## 3. AdMob (ads, next to the in-app purchases)

| # | Step | Status |
|---|---|---|
| 3.1 | AdMob account in good standing, payment profile and tax info completed (needed to get paid, not needed for approval). | Owner |
| 3.2 | Add the app to AdMob as **iOS**, with the bundle id above. Copy the **App ID** (`ca-app-pub-XXXX~YYYY`). | Owner |
| 3.3 | Create two ad units: **Banner** and **Rewarded**. Name them clearly (for example `careerkit_ios_banner`, `careerkit_ios_rewarded`). Reward amount 1, type "export". The app grants one export per completed video regardless of these values. | Owner |
| 3.4 | The three ids are in `Config/Release.xcconfig` (`ADMOB_APP_ID`, `ADMOB_BANNER_UNIT_ID`, `ADMOB_REWARDED_UNIT_ID`, publisher `pub-8621573128492952`). The Debug config stays on Google test ids. | Done |
| 3.5 | Privacy and messaging: create and publish the **GDPR** message (consent form) and, if wanted, the US state regulations message and an IDFA explainer. The app already calls the UMP SDK. A message that is not published means no consent form is shown. | Owner |
| 3.6 | Block sensitive ad categories in Blocking controls (gambling, dating, political, weight loss and similar) so the 4+ rating and a job-seeker audience stay consistent. | Owner |
| 3.7 | `app-ads.txt` with exactly this line: `google.com, pub-8621573128492952, DIRECT, f08c47fec0942fa0`. It must be served at the **root of the host used in the Marketing URL** (`https://<host>/app-ads.txt`). The user-site repo `EcomswiftLLC/ecomswiftllc.github.io` serves it at `https://ecomswiftllc.github.io/app-ads.txt` (free GitHub Pages), the root of the host in the Marketing URL `https://ecomswiftllc.github.io/careerkit/`. Check AdMob > Apps > app-ads.txt shows the file as found (can take up to 24 hours). | Done, owner confirms in AdMob |
| 3.8 | `SKAdNetworkItems` in Info.plist holds Google's list of 50 ids (ads owner, fetched 2026-11-16). Re-check against Google's current list shortly before release. | Done, re-check |
| 3.9 | New ad units can have limited fill for a few days, and Apple's reviewers may not get a rewarded video. Handled in the app: when no video can be shown the sheet says so and the person can use a 3-export pack or Premium (see section 7). | Done |
| 3.10 | Ads are limited to general-audience content in code (`maxAdContentRating = .general`), matching the 4+ rating. Child-directed tags are not set. | Done |

## 4. Website and legal URLs (must be live before submission)

| # | Step | Status |
|---|---|---|
| 4.1 | Static site in `website/careerkit/` (home, privacy, terms, support, sitemap, robots). It matches build 11 (1.0.0) and stays that way until 1.1.0 is released. The 1.1.0 wording is built into `website/draft-1.1/careerkit/` with `CAREERKIT_EDITION=1.1 python website/build_site.py`, from `docs/legal/next-1.1/`. Publish it to the live site only when 1.1.0 goes live. | Done (1.0), Owner (publish 1.1 at release) |
| 4.2 | Live and returning 200 on the free GitHub Pages host `ecomswiftllc.github.io`: `/careerkit/`, `/careerkit/privacy/`, `/careerkit/terms/`, `/careerkit/support/`. These are the URLs used in the listing and in the app. | Done |
| 4.3 | Lawyer review of `docs/legal/privacy-policy.md`, `terms-of-use.md` and the 1.1.0 drafts in `docs/legal/next-1.1/` (purchases, refunds, restore). The drafts are plain-language text, not legal advice. Then re-generate the pages with `python website/build_site.py`. | Owner |
| 4.4 | `support@ecomswiftllc.com` receives mail and someone answers it. | Owner |
| 4.5 | After the app is approved: add the real App Store link to the site (remove the coming-soon state), and add the Smart App Banner meta tag with the numeric Apple id. | Owner |

## 5. App Store Connect listing

| # | Step | Status |
|---|---|---|
| 5.1 | Paste name, subtitle, keywords, promotional text, description, What's New from `metadata.md` (1.1.0 text, verified by `design/check_store_metadata.py`). The old "no purchases" claims are gone: the listing now says free to start, with ads and optional purchases. | Done (text), Owner (paste) |
| 5.1a | Localized listings: add Spanish (Spain), French (France), German and Chinese (Simplified) in App Store Connect and paste each block from `metadata-localized.md` (verified by `design/check_store_metadata.py`). Screenshots are needed per language, captured from the CI localized screenshot artifact `screenshots-l10n`. | Done (text), Owner (paste, screenshots) |
| 5.2 | Category Business, secondary Productivity. | Owner |
| 5.3 | Support, marketing, privacy policy URLs. Terms link in the description or a custom EULA. | Owner |
| 5.4 | Copyright `2026 Ecom Swift LLC`. | Owner |
| 5.5 | Age rating questionnaire (expect 4+). Not Made for Kids. Re-answer it for 1.1.0: the form now asks about in-app purchases and ads. | Owner |
| 5.6 | App Privacy: answer from `app-privacy.md`; the privacy policy URL is required. The tracking answer must be **Yes** for Device ID and Advertising Data (the ATT prompt is shown). `NSPrivacyTracking` in the manifest stays `false` for ITMS-91064; the two are different declarations. | Owner |
| 5.7 | Screenshots (guideline 2.3.7: do not show prices in the gallery; the paywall screenshot is only the in-app purchase review image): 8 for 6.9-inch iPhone, 8 for 13-inch iPad, 8 for 6.5-inch only if asked. Captured from the running app, framed with `design/make_store_screenshots.py`. Raw simulator screens already exist as CI artifacts (`screenshots`, `screenshots-ipad-dark`, `screenshots-l10n`); they only need framing and a check of the pixel sizes. | Mac, then Owner |
| 5.8 | Optional app preview video from the storyboard. | Mac, optional |
| 5.9 | App Review information: contact name, phone and email, no sign-in required, review notes from `metadata.md` (they explain the pack, Premium, Restore purchases and the sandbox). | Owner |
| 5.10 | Accessibility nutrition labels (optional in App Store Connect). Fill in only what has been tested with VoiceOver, Dynamic Type and Reduce Motion. | Open, optional |
| 5.11 | Version release: choose manual release so the website can be updated the same day. | Owner |

## 6. TestFlight

| # | Step | Status |
|---|---|---|
| 6.0a | **Sandbox purchase test (none of this could be run during development):** on a real device, sign in with a sandbox Apple Account (Settings > Developer > Sandbox Apple Account). Buy the 3-export pack, export once and check 2 are left; cancel the share sheet and check nothing is used; buy Premium and check exports are unlimited; delete the app, reinstall and check the unused exports and Premium are still there (they are kept in the Keychain), then tap Restore purchases and check nothing is added twice; try a declined and a pending payment. Also test with Airplane mode (prices unavailable, Try again works) and, if possible, with the product ids missing (no products state). | Owner |
| 6.0 | **Before any TestFlight build reaches a phone:** TestFlight builds use the Release configuration, so they request **real** ads with the production ids. Register every tester's iPhone and iPad as a test device in AdMob (Settings > Test devices, using the IDFA or the id printed in the Xcode console) before installing. Never tap a production ad, never reload ads on purpose, and never ask friends to click. Invalid traffic on this account can suspend ad serving for every app on it. | Owner |
| 6.1 | Wait for the uploaded build to finish processing. | Mac/CI |
| 6.2 | Internal testing (up to 100 App Store Connect users, no review). Test on a real iPhone and an iPad. | Owner |
| 6.3 | Run the test script below with a Debug build (test ids) first. The TestFlight build has production ids: only on registered test devices (6.0). | Owner |
| 6.4 | Optional external group (needs a short Beta App Review). | Owner, optional |

Test script (about 15 minutes):
1. Fresh install. Welcome screens, UMP form (use a VPN or the UMP debug geography only in a debug build), ATT prompt. Deny both and confirm the app still works.
2. Create a resume from a template, edit, preview, change colours and fonts.
3. Create a blank resume. Add and hide sections.
4. ATS check on a resume with missing items and on a complete one.
5. Cover letter from a resume.
6. Export: watch the rewarded video to the end, then Share, Files and Print. Confirm that a second export of the same document asks for another video, a pack or Premium. Then do the sandbox purchases in 6.0a.
7. Close the ad early and confirm no export is granted and Watch again is offered. If a video starts late (after the short wait) and is watched to the end, confirm the export still unlocks.
8. Airplane mode: writing, editing, previewing, cover letters and the ATS check work. Open the export sheet: it says prices cannot be reached and offers Try again (it never offers a free export). Go back online and open the sheet again: the prices load. Repeat with the consent form declined (EEA debug geography): the video is not offered, the pack and Premium are.
9. Profile: Export backup, then Delete all local data (two steps). Relaunch and confirm the app is empty.
10. Dark mode, largest Dynamic Type, VoiceOver on the editor, iPad portrait and landscape.

## 7. Open risks

1. **Rewarded video and the reviewer.** In 1.1.0 the reviewer can export with a sandbox purchase of the pack or Premium, so a missing rewarded video no longer blocks the review. The risk moves to the products: they must be created, priced, localized and attached to the 1.1.0 version, or the app finds no products. In that case the sheet says "Purchases are not available right now" and offers Export without video, so an export is never blocked (this free path is only for an empty catalog, never for an unreachable store; see `../EXPORT-GATE-IOS.md`). Build 11 (1.0.0) has no purchases and offers Export without video whenever no video can play.
1a. **In-app purchase review (guideline 3.1.1).** Purchases use StoreKit only, a clear price is shown before buying, Restore purchases is on the export sheet and in Profile, and the app does not link out to other ways to pay. Exports already bought are never taken away by an update.
2. **Apple guideline on ads.** Rewarded ads that gate a feature are allowed. The ad must be clearly opt-in, which the design already does. No interstitials, no ads in the editor.
3. **Name availability** of `Resume & CV Maker: CareerKit` is only known after creating the app record.
4. **Screenshots with ads.** Never submit a screenshot that shows a test ad label.
5. **Descriptions of UI.** The review notes and screenshot plan name buttons and screens (for example "Profile > Delete all local data", "Ad privacy choices", "Watch an ad to export", "Restore purchases"). Check each name against the real UI once the app runs and edit the text if the labels differ.

## 8. After approval

1. Release manually, confirm the listing is live, update the site (section 4.5).
2. Add the real review prompt only through Apple's `requestReview` API (no custom incentive, no star claims anywhere).
3. Keep the AdMob console and the UMP message in step with any new SDK version.
