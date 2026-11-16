# Assets handoff (icon, store, legal, website, README)

Owner: assets. Nothing in the app was compiled or run (no Mac). Everything below was written and checked on Windows with Python, Pillow and Playwright (Chromium).

## What exists

### 1. App icon and asset catalog
| File | Notes |
|---|---|
| `Sources/Resources/Assets.xcassets/Contents.json` | root catalog file |
| `.../AppIcon.appiconset/AppIcon-1024.png`, `-dark.png`, `-tinted.png`, `Contents.json` | 1024 x 1024, RGB, no alpha, square corners (iOS masks them). Single-size universal iOS icon with dark and tinted appearances, valid for Xcode 15 and 16 |
| `.../AccentColor.colorset/Contents.json` | forest `#1F4D3A`, dark variant `#6FB594` (same as `CK.Palette.forest`) |
| `.../LaunchBackground.colorset/Contents.json` | ivory `#FAF7F0`, dark `#141614` (same as `CK.Palette.ivory`). `Info.plist` already points `UILaunchScreen` at `LaunchBackground` |
| `design/make_icon.py` | generator (4x supersampled, Pillow and numpy). `design/icon/` has review copies. `design/icon-philosophy.md` is the canvas-design philosophy ("Folded Ascent") |

Concept: a K made from an upright stem, a leg, and a champagne ascending arm at 45 degrees that points at a folded page corner, on a forest field. All four JSON files parse as valid JSON (checked). The asset catalog has not been opened in Xcode.

### 2. Store documents (`docs/store/`)
- `metadata.md`: name (25/30), subtitle (27/30), keywords (94/100 bytes, no repeats from name or subtitle), promo text (169/170), description (about 2400/4000), What's New, category (Business primary, Productivity secondary, reasoning inside), age rating answers, URLs, copyright, review notes with test steps, 8-screen screenshot plan with captions and layout notes (sizes 1320x2868, 1284x2778, 2064x2752), 25-second app preview storyboard, icon concepts note.
- `app-privacy.md`: App Privacy draft. Its data table matches the questionnaire in `docs/handoff/ads.md`.
- `submission-checklist.md`: every App Store Connect step with Done / Owner / Mac or CI / Open. No banking or tax step is needed (free app). Includes the EU trader status and `app-ads.txt` items.
- Tools: `design/check_store_metadata.py` re-checks every limit (run it after editing `metadata.md`; it passed). `design/make_store_screenshots.py` adds the caption frame to raw simulator captures dropped in `design/screens-raw/<iphone-6.9|iphone-6.5|ipad-13>/01.png to 08.png`. It was tested once on a synthetic image and the test output was deleted.

### 3. Legal drafts (`docs/legal/`)
`privacy-policy.md` and `terms-of-use.md`, matching how the app works as of the current source: local storage, no account, AdMob with UMP and ATT, rewarded ad needed for export, no resume content sent anywhere, deletion in the Profile tab (Delete all local data), children not targeted. Company details as given. **Both start with a DRAFT FOR LEGAL REVIEW notice.** The website build strips that notice, so the published pages carry no draft marker. The lawyer review must happen before the pages go live. Open choices a lawyer should decide: liability cap (50 USD), governing law (Wyoming), CCPA "sharing" wording, GDPR role wording.

### 4. Website (`website/careerkit/`)
- Source: `website/build_site.py` generates `index.html`, `privacy/index.html`, `terms/index.html`, `support/index.html` (legal pages come from the Markdown). `website/make_site_assets.py` makes the icons and the 1200x630 social image. Present now: `assets/site.css`, `assets/*.png|svg`, `sitemap.xml`, `robots.txt`.
- Design: ivory, charcoal, forest, champagne, system serif and sans stacks, no external requests (verified with Playwright: zero non-local requests, no console errors), light and dark themes, responsive. The hero shows schematic page diagrams of real layout types (labelled as diagrams, not screenshots). Template facts on the page come from the source: 30 templates (19 single column, 4 left sidebar, 3 right sidebar, 4 header with two columns), group counts, 16 iOS fonts, 10 cover letters. Structured data: SoftwareApplication and FAQPage JSON-LD, no ratings. Coming-soon state is plain text, not a fake App Store link.
- Design review: screenshots at 1440 and 390 px in light and dark were reviewed with the design-critique, accessibility-review and ux-copy skills. Fixed: logo legibility, checklist markers, intro paragraph styling on legal pages, non-button status label, footer and brand tap targets (44 px), decorative diagrams hidden from screen readers, heading and caption wording. Contrast ratios computed (body 14.7:1, muted text 6.0:1, links 9.0:1, dark mode 8.0:1 or better). No horizontal overflow at 390 px. Keyboard tab order checked in Chromium. Not tested: a real screen reader, Safari, real phones.

## IMPORTANT: the HTML pages are not built in the repository yet

A privacy check in this environment refused to let me write the support email address next to the company identity inside the build script. The script therefore reads the address from an environment variable, and a person has to set it. The address itself is already printed in `docs/legal/*.md`. To build:

```
# PowerShell
$env:CAREERKIT_SUPPORT_EMAIL = "<the support address from docs/legal>"
python website/build_site.py
```

This writes the four HTML pages into `website/careerkit/`. The pages show the address as selectable text, not as a `mailto:` link. I reviewed a build made with a throwaway address (not committed), so the layout and checks above apply to the real build, but the real build has not been seen. If you want a clickable mail link, add it after the owner approves putting the address in a URL.

## What could not be verified

- No compile, no simulator, no device. Icon appearance on a real home screen at 60 pt is unchecked.
- UI labels in the store and legal text were checked against the Swift source on 2026-11-16 (Profile tab, "Delete all local data", "Ad privacy choices", "Watch an ad to export", "Try again", five onboarding pages). Re-check after the editor and appui owners change copy.
- Screenshots and the app preview do not exist: they need the running app. The plan, captions, size spec and framing script are ready.
- Apple's age rating and App Privacy questionnaires change; the answers are drafts to compare with the live forms. Google's AdMob data table was not re-fetched by me; I followed `docs/handoff/ads.md`.
- Keywords and category are judgement, not data. No search volume was checked.
- Name availability of "Resume & CV Maker: CareerKit" is only known after the app record exists.
- The app links to `https://ecomswiftllc.github.io/careerkit/privacy` and `/terms` (no trailing slash, see `CKLinks.swift`). The static site uses folder URLs with a trailing slash, so the host must serve both (most do with a redirect). Check this when deploying.

## Open product decision that touches these documents

`docs/handoff/ads.md` says a person who declines the consent form where one is required cannot export, because export needs a completed rewarded video. The privacy policy, terms, FAQ and review notes now say this plainly. If the owner later allows an export when ads cannot be requested, update those four places. This is also the biggest App Review risk (a reviewer with no ad fill could not export).

## Owner actions

1. Set the support address variable and run `python website/build_site.py` (see above), then publish `website/careerkit/` so the four URLs return 200. The host for `www.ecomswiftllc.com` and how it serves a static folder under `/careerkit/` is not known to me. If that domain is on a hosted site builder, either host the folder on a static host and route `/careerkit/` to it, or recreate the pages there.
2. Lawyer review of the privacy policy and terms, then re-run the build.
3. Replace the test ids in `Config/Release.xcconfig` with production AdMob ids and publish the AdMob consent messages (checklist section 3).
4. Create the app record in App Store Connect, register `com.ecomswift.careerkit`, declare EU trader status, publish `app-ads.txt` with the real AdMob publisher id.
5. After the first macOS build: capture the 8 screenshots per size, run `design/make_store_screenshots.py`, upload, and check the icon on a real device.
6. Decide the consent and export behaviour (above) before submitting.
7. After approval: replace the coming-soon text on the home page with the App Store link.
