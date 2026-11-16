# Resume & CV Maker: CareerKit

CareerKit is a native SwiftUI resume and cover letter builder for iPhone and iPad (iOS 17 or later). The App Store name is **Resume & CV Maker: CareerKit**, the home-screen name is **CareerKit**, the bundle id is `com.ecomswift.careerkit`.

- 100 percent free. No StoreKit, no purchases, no account.
- Google AdMob is the only monetisation: adaptive banners on browse screens and one rewarded video that unlocks one document export.
- Documents are stored on the device. No paid AI service, no upload of resume content.
- 30 resume templates, 10 cover letter templates, an ATS check that gives general guidance, PDF export.

The rules every contributor follows are in `docs/ARCHITECTURE.md`. Read it first.

## Where this project can be built

The project is edited on Windows, but **it can only be compiled on macOS** with Xcode 26 or later (Apple requires the iOS 26 SDK for App Store uploads). Two ways:

1. A Mac with Xcode (steps below).
2. The GitHub Actions workflow `.github/workflows/ios.yml`, which runs on a `macos-26` runner on every push to `main`, every pull request and on demand. It installs XcodeGen, generates the project, resolves the Swift packages, then builds and runs the unit tests on an iPhone simulator. Download the logs from the run's artifacts when something fails.

Nothing in this repository has been compiled yet. The first CI run is the first real build, so expect to fix compile errors.

## Open, build and run (Mac)

```sh
brew install xcodegen          # once
xcodegen generate              # creates CareerKit.xcodeproj from project.yml (the .xcodeproj is not committed)
open CareerKit.xcodeproj
```

Xcode resolves two Swift packages on first open: Google Mobile Ads (`from: 12.0.0`) and Google User Messaging Platform (`from: 3.0.0`). If a package fails to resolve, use File > Packages > Reset Package Caches.

**Simulator:** pick the `CareerKit` scheme and an iPhone or iPad simulator, then press Run. Or from a terminal:

```sh
xcodebuild -project CareerKit.xcodeproj -scheme CareerKit \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
xcodebuild -project CareerKit.xcodeproj -scheme CareerKit \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test
```

**Device:** connect an iPhone or iPad, enable Developer Mode on it, choose it as the run destination. Signing is automatic and uses the team id set in `project.yml` (`DEVELOPMENT_TEAM`). If you are on another team, change that value, run `xcodegen generate` again and let Xcode create the profile for `com.ecomswift.careerkit`.

After editing `project.yml` or adding or removing source files, run `xcodegen generate` again.

## AdMob ids

Ad ids are never hard coded in Swift. They flow from the xcconfig files into `Info.plist`:

| xcconfig key | Info.plist key |
|---|---|
| `ADMOB_APP_ID` | `GADApplicationIdentifier` |
| `ADMOB_BANNER_UNIT_ID` | `CKBannerAdUnitID` |
| `ADMOB_REWARDED_UNIT_ID` | `CKRewardedAdUnitID` |

- `Config/Debug.xcconfig` holds Google's public **test** ids. Leave it that way.
- `Config/Release.xcconfig` currently holds the same test ids so that a release build made today cannot serve real ads. **Replace all three with the production values from the AdMob console before submitting to the App Store**, and never ship test ids. Steps to create the AdMob iOS app and the two ad units are in `docs/store/submission-checklist.md` (section 3).
- Also check `SKAdNetworkItems` in `Sources/Resources/Info.plist` against Google's current list before release.

## Legal URLs and the website

The App Store listing and the in-app Profile screen point at:

| Page | URL |
|---|---|
| Marketing | `https://ecomswiftllc.github.io/careerkit/` |
| Privacy policy | `https://ecomswiftllc.github.io/careerkit/privacy/` |
| Terms of use | `https://ecomswiftllc.github.io/careerkit/terms/` |
| Support | `https://ecomswiftllc.github.io/careerkit/support/` |

The text lives in `docs/legal/privacy-policy.md` and `docs/legal/terms-of-use.md`. **Both are drafts that a lawyer should review.** The static site in `website/careerkit/` is generated from them:

```sh
pip install pillow numpy                 # only for the image assets
python website/make_site_assets.py       # icon, favicon, social image (already generated)

# The public support address is read from an environment variable so a person sets it, not the script.
export CAREERKIT_SUPPORT_EMAIL="<support address, same one as in docs/legal>"    # PowerShell: $env:CAREERKIT_SUPPORT_EMAIL = "..."
python website/build_site.py             # writes index.html, privacy/, terms/, support/
```

The pages use system fonts only and make no external requests. Upload the contents of `website/careerkit/` so that the four URLs above return 200. Before release, the draft notice in the Markdown files is removed automatically from the web pages, but the lawyer review still has to happen. See `docs/handoff/assets.md` for what is and is not verified.

## Store assets

| What | Where |
|---|---|
| App icon (light, dark, tinted 1024 px) and colour sets | `Sources/Resources/Assets.xcassets/` |
| Icon generator and design notes | `design/make_icon.py`, `design/icon-philosophy.md` |
| Store text, review notes, screenshot plan | `docs/store/metadata.md` (check limits with `python design/check_store_metadata.py`) |
| App Privacy answers draft | `docs/store/app-privacy.md` |
| Step-by-step submission list | `docs/store/submission-checklist.md` |
| Screenshot frames from raw simulator captures | `python design/make_store_screenshots.py` |

## Archive and submit

1. Make sure production AdMob ids are in `Config/Release.xcconfig`, the version is right in `project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) and `xcodegen generate` has been run.
2. In Xcode choose **Any iOS Device (arm64)** and **Product > Archive**. Or from a terminal:
   ```sh
   xcodebuild -project CareerKit.xcodeproj -scheme CareerKit -configuration Release \
     -destination 'generic/platform=iOS' -archivePath build/CareerKit.xcarchive archive
   ```
3. In the Organizer choose **Distribute App > App Store Connect > Upload**. The Transporter app also works with an exported `.ipa`.
4. In App Store Connect wait for processing, test with TestFlight, complete the listing from `docs/store/metadata.md` and `app-privacy.md`, then submit for review.

The full list, with what is done and what needs the account owner, is `docs/store/submission-checklist.md`. No banking or tax setup is needed in App Store Connect because the app is free.

## Project layout

```
project.yml                 XcodeGen definition (targets, packages, build settings)
Config/                     Debug.xcconfig and Release.xcconfig (AdMob ids)
Sources/
  App/                      app entry, tabs, app state (appui)
  Ads/                      AdMob, consent, banner, rewarded export gate (ads)
  DesignSystem/             Theme.swift colours, type, components
  Features/                 Onboarding, Home, MyResumes, Templates, Profile, Editor, Preview, CoverLetters, ATS
  Models/                   Resume and CoverLetter data models
  Persistence/              on-device JSON document store (engine)
  Render/                   PDF renderer and validator (engine)
  Templates/                template specs and libraries (templates)
  Resources/                Info.plist, Assets.xcassets, PrivacyInfo.xcprivacy, Localizable.xcstrings (en, es, fr, de, zh-Hans)
Tests/                      unit tests
design/                     icon generator and artwork, store screenshot tooling
tools/                      localization tooling (l10n_extract.py) and translator part files (l10n_parts/)
docs/                       ARCHITECTURE.md, store/, legal/, handoff/
website/                    static marketing, privacy, terms and support pages
.github/workflows/ios.yml   macOS CI: generate, build, test
```

Some of these folders are filled by other owners and may be empty or incomplete in a given checkout.
