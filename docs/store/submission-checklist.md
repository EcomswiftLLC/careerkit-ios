# Submission checklist: Resume Builder: CareerKit

Legend: **Done** = finished in this repository. **Owner** = needs the account holder (logins, payments, legal identity). **Mac/CI** = needs macOS (Xcode) or the GitHub Actions macOS runner. **Open** = decision or check still to be made.

Banking and tax forms in App Store Connect are **not needed**. The app is free with no in-app purchases, so the Paid Applications Agreement, bank account and US tax forms are not required to release it. (AdMob has its own payment profile, see section 3.)

## 1. Apple Developer account and app record

| # | Step | Status |
|---|---|---|
| 1.1 | Active Apple Developer Program membership for the team in `project.yml` (`DEVELOPMENT_TEAM: N84NGN3KSH`). Confirm the team id is the right one for Ecom Swift LLC. | Owner |
| 1.2 | Register explicit App ID `com.ecomswift.careerkit` (Certificates, Identifiers & Profiles). No special capabilities are needed (no push, no IAP, no iCloud). | Owner |
| 1.3 | Create the app in App Store Connect: name `Resume Builder: CareerKit`, English (U.S.), bundle id above, SKU `careerkit-ios`, full access. If the name is taken use the fallbacks in `metadata.md`. | Owner |
| 1.4 | EU Digital Services Act trader status: as a business, Ecom Swift LLC declares itself a trader in App Store Connect (Business > Compliance). Address, phone and email are shown publicly in the EU. If the owner does not want that, remove EU countries from Availability. | Owner |
| 1.5 | Set price to Free, availability, and no in-app purchases. | Owner |

## 2. Build and signing

| # | Step | Status |
|---|---|---|
| 2.1 | Project generates from `project.yml` with XcodeGen. Assets catalog, AppIcon, AccentColor and LaunchBackground exist. | Done (not compiled on this PC) |
| 2.2 | First real compile on macOS (CI workflow `.github/workflows/ios.yml` or a Mac). Fix any compile errors reported by CI. | Mac/CI |
| 2.3 | Replace the three Google test ids in `Config/Release.xcconfig` with production ids (section 3). Never ship test ids. | Owner + Mac |
| 2.4 | Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `project.yml` when needed (now 1.0.0 build 1). | Done |
| 2.5 | Archive in Xcode (Product > Archive, Any iOS Device) with automatic signing. Upload through the Organizer, or export and upload with Transporter. | Mac |
| 2.6 | Confirm the icon shows (1024 px, no alpha) and the build passes App Store Connect processing. | Mac |
| 2.7 | Export compliance: `ITSAppUsesNonExemptEncryption` is already `false` in Info.plist, so the question is skipped for each build. The app only uses the standard HTTPS stack of iOS (through the ad SDK). If App Store Connect still asks: "Does your app use encryption? Yes, only exempt standard encryption", no French declaration needed. | Done, confirm in ASC |

## 3. AdMob (the only monetisation)

| # | Step | Status |
|---|---|---|
| 3.1 | AdMob account in good standing, payment profile and tax info completed (needed to get paid, not needed for approval). | Owner |
| 3.2 | Add the app to AdMob as **iOS**, with the bundle id above. Copy the **App ID** (`ca-app-pub-XXXX~YYYY`). | Owner |
| 3.3 | Create two ad units: **Banner** and **Rewarded**. Name them clearly (for example `careerkit_ios_banner`, `careerkit_ios_rewarded`). Reward amount 1, type "export". The app grants one export per completed video regardless of these values. | Owner |
| 3.4 | Put the three ids in `Config/Release.xcconfig`: `ADMOB_APP_ID`, `ADMOB_BANNER_UNIT_ID`, `ADMOB_REWARDED_UNIT_ID`. The Debug config stays on Google test ids. | Owner + Mac |
| 3.5 | Privacy and messaging: create and publish the **GDPR** message (consent form) and, if wanted, the US state regulations message and an IDFA explainer. The app already calls the UMP SDK. A message that is not published means no consent form is shown. | Owner |
| 3.6 | Block sensitive ad categories in Blocking controls (gambling, dating, political, weight loss and similar) so the 4+ rating and a job-seeker audience stay consistent. | Owner |
| 3.7 | `app-ads.txt`: publish `https://ecomswiftllc.com/app-ads.txt` (root of the domain used as the Marketing URL) with the AdMob line `google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0` using the owner's real publisher id. This protects ad revenue. It cannot be created here because the publisher id is not known. | Owner |
| 3.8 | `SKAdNetworkItems` in Info.plist holds Google's list of 50 ids (ads owner, fetched 2026-11-16). Re-check against Google's current list shortly before release. | Done, re-check |
| 3.9 | New ad units can have limited fill for a few days, and Apple's reviewers may not get a rewarded video. See the open risk in section 7. | Open |

## 4. Website and legal URLs (must be live before submission)

| # | Step | Status |
|---|---|---|
| 4.1 | Static site in `website/careerkit/` (home, privacy, terms, support, sitemap, robots). | Done |
| 4.2 | Deploy so these return 200: `/careerkit/`, `/careerkit/privacy/`, `/careerkit/terms/`, `/careerkit/support/` on `www.ecomswiftllc.com`. The way to host a static folder under that domain is not decided (see handoff). | Owner |
| 4.3 | Lawyer review of `docs/legal/privacy-policy.md` and `terms-of-use.md`, then re-generate the pages with `python website/build_legal.py`. | Owner |
| 4.4 | `support@ecomswiftllc.com` receives mail and someone answers it. | Owner |
| 4.5 | After the app is approved: add the real App Store link to the site (remove the coming-soon state), and add the Smart App Banner meta tag with the numeric Apple id. | Owner |

## 5. App Store Connect listing

| # | Step | Status |
|---|---|---|
| 5.1 | Paste name, subtitle, keywords, promotional text, description, What's New from `metadata.md` (verified by `design/check_store_metadata.py`). | Done (text), Owner (paste) |
| 5.2 | Category Business, secondary Productivity. | Owner |
| 5.3 | Support, marketing, privacy policy URLs. Terms link in the description or a custom EULA. | Owner |
| 5.4 | Copyright `2026 Ecom Swift LLC`. | Owner |
| 5.5 | Age rating questionnaire (expect 4+). Not Made for Kids. | Owner |
| 5.6 | App Privacy: answer from `app-privacy.md`; the privacy policy URL is required. | Owner |
| 5.7 | Screenshots: 8 for 6.9-inch iPhone, 8 for 13-inch iPad, 8 for 6.5-inch only if asked. Captured from the running app, framed with `design/make_store_screenshots.py`. **Not made yet**, the app has not been run. | Mac, then Owner |
| 5.8 | Optional app preview video from the storyboard. | Mac, optional |
| 5.9 | App Review information: contact name, phone and email, no sign-in required, review notes from `metadata.md`. | Owner |
| 5.10 | Accessibility nutrition labels (optional in App Store Connect). Fill in only what has been tested with VoiceOver, Dynamic Type and Reduce Motion. | Open, optional |
| 5.11 | Version release: choose manual release so the website can be updated the same day. | Owner |

## 6. TestFlight

| # | Step | Status |
|---|---|---|
| 6.1 | Wait for the uploaded build to finish processing. | Mac/CI |
| 6.2 | Internal testing (up to 100 App Store Connect users, no review). Test on a real iPhone and an iPad. | Owner |
| 6.3 | Run the test script below, with **test ids** first and **production ids** in the final candidate. | Owner |
| 6.4 | Optional external group (needs a short Beta App Review). | Owner, optional |

Test script (about 15 minutes):
1. Fresh install. Welcome screens, UMP form (use a VPN or the UMP debug geography only in a debug build), ATT prompt. Deny both and confirm the app still works.
2. Create a resume from a template, edit, preview, change colours and fonts.
3. Create a blank resume. Add and hide sections.
4. ATS check on a resume with missing items and on a complete one.
5. Cover letter from a resume.
6. Export: watch the rewarded video to the end, then Share, Files and Print. Confirm that a second export of the same document asks for another video.
7. Close the ad early and confirm no export is granted.
8. Airplane mode: writing, editing, previewing, cover letters and the ATS check work. Export is unavailable until the rewarded video can load, and the export sheet says so.
9. Profile: Export backup, then Delete all local data (two steps). Relaunch and confirm the app is empty.
10. Dark mode, largest Dynamic Type, VoiceOver on the editor, iPad portrait and landscape.

## 7. Open risks

1. **Rewarded video can block the reviewer.** Export needs a completed rewarded video, and a video needs ad consent. A brand-new ad unit, a region without fill, or a person who declines the consent form where one is required can leave them unable to export, which can be rejected as non-working. `docs/handoff/ads.md` lists this as a known product gap that needs an owner decision (for example allowing export when ads cannot be requested). Decide before submission and update the review notes to match. This is an app behaviour decision, so it is left open here.
2. **Apple guideline on ads.** Rewarded ads that gate a feature are allowed. The ad must be clearly opt-in, which the design already does. No interstitials, no ads in the editor.
3. **Name availability** of `Resume Builder: CareerKit` is only known after creating the app record.
4. **Screenshots with ads.** Never submit a screenshot that shows a test ad label.
5. **Descriptions of UI.** The review notes and screenshot plan name buttons and screens (for example "Profile > Delete all local data", "Ad privacy choices", "Watch an ad to export"). Check each name against the real UI once the app runs and edit the text if the labels differ.

## 8. After approval

1. Release manually, confirm the listing is live, update the site (section 4.5).
2. Add the real review prompt only through Apple's `requestReview` API (no custom incentive, no star claims anywhere).
3. Keep the AdMob console and the UMP message in step with any new SDK version.
