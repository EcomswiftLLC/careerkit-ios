# App Store metadata: Resume & CV Maker: CareerKit

Language: English (U.S.). Bundle id `com.ecomswift.careerkit`. Price: Free. No in-app purchases.

Character and byte limits are checked by `python design/check_store_metadata.py`. The script reads the first fenced block under each heading below, so keep one fenced block per field and re-run it after any edit.

## App Name
Limit 30 characters. Current: 28.

```
Resume & CV Maker: CareerKit
```

If App Store Connect says the name is taken, fall back in this order (all within 30): `Resume Builder & CV: CareerKit` (30), `CV & Resume Maker: CareerKit` (28), `Resume Builder: CareerKit` (25). Do not put Word, Google, Docs or any other company's trademark in the name, subtitle or keywords.

## Subtitle
Limit 30 characters. Current: 25.

```
Templates & Cover Letters
```

## Keywords
Limit 100 bytes. No spaces after commas. Words already in the name or subtitle (resume, cv, maker, careerkit, templates, cover, letters) are left out because Apple indexes them already. No competitor or third-party trademarks. Apple combines single words into phrases, so "cover letter" and "curriculum vitae" are stored as two-word phrases the user can still search either way.

```
builder,pdf,docx,ats,keywords,curriculum vitae,student,fresher,import,job,application,interview
```

## Promotional Text
Limit 170 characters. Can be changed at any time without a new build.

```
Pick from 30 templates, import your old resume, match it to a job ad, then export to PDF or Word. Free with ads, works offline, and your documents stay on your device.
```

## Description
Limit 4000 characters. Plain text only (App Store Connect does not render formatting).

```
Resume & CV Maker: CareerKit helps you make a clear, well-formatted resume and cover letter on your iPhone or iPad. Choose a template, type in your details, watch the page update, and export to PDF or Word when you are ready.

WHAT IS INSIDE

30 resume templates in six groups: Professional, Modern, Creative, Academic, Entry Level and Technical. Layouts include single column, left and right sidebar, and banner headers.

A blank resume if you would rather start from nothing and choose every section yourself.

Full control over the details: add, hide and reorder sections, change the accent colour, fonts, text size, line spacing and margins, and add an optional photo.

10 cover letter templates that share the look of your resume, so the two documents match.

An ATS check that reads your resume and gives general guidance on headings, contact details, dates, layout and length. It is advice only. It is not a score from any employer's system and it cannot promise any result.

Several resumes in one place. Keep a version for each kind of job, then duplicate, rename or archive them, and compare two versions side by side.

A4 or US Letter page size.

EXPORT YOUR WAY: PDF with selectable text, Word (.docx), Rich Text, plain text for online forms, or a web page. Share a file, save it to Files or print the PDF. A backup option saves a copy of everything to one file you can keep anywhere.

IMPORT YOUR OLD RESUME: bring in a PDF or paste the text, check what was found section by section, and carry on editing in a template you like. Text-based PDFs work best. Scanned pages are not read.

JOB AD KEYWORD CHECK: paste a job ad and see which of its key terms your resume already uses and which it leaves out. It is a reading aid, not a score. Add only what is true for you.

Writing, editing and previewing work offline. There is no account to create, and your resumes and letters are stored on your device only.

FREE, WITH ADS

CareerKit is free. There is no subscription and nothing to buy.

The app is paid for by ads from Google AdMob. A banner ad can appear on browse screens such as Home, My Resumes, Templates, Cover Letters and Profile. There are no ads in the editor or the preview.

To export a finished document you choose to watch one short rewarded video. That one video covers one export of that document, and the export stays unlocked for 24 hours. If no video is available, for example when you are offline, you can export without one. Writing, editing, previewing, cover letters and the ATS check never need an ad.

Where the law requires it, the app asks for your consent before showing personalised ads, and you can change your choice later in the Profile tab.

YOUR DATA

Your resume content never leaves your device. CareerKit has no account system and does not upload what you write. You can delete all of your data from the Profile tab.

Questions or ideas? Visit https://ecomswiftllc.github.io/careerkit/support/ or write to support@ecomswiftllc.com.
```

## What's New
Limit 4000 characters. Version 1.0.0.

```
First release. 30 resume templates, 10 matching cover letter templates, full style controls, an ATS check with general guidance, a job ad keyword check, resume import, and export to PDF, Word, Rich Text, plain text and web page. Free, with ads.
```

## Category
Primary: **Business**. Secondary: **Productivity**.

Why: people search for resume tools while looking for work, and Business is the category Apple associates with careers and professional documents. Productivity is the closest second fit because the app is a document editor. Both choices can be changed with any later version, so if search data after launch favours Productivity as primary, swap them.

## Age rating
Answer the questionnaire in App Store Connect as follows. Apple has changed this form before, so check each question against the live wording.

| Question | Answer |
|---|---|
| Every content descriptor (cartoon or fantasy violence, realistic violence, prolonged graphic or sadistic violence, sexual content or nudity, graphic sexual content and nudity, profanity or crude humor, horror or fear themes, mature or suggestive themes, alcohol, tobacco or drug use or references, simulated gambling, contests) | None |
| Guns or other weapons | None |
| Medical or treatment information / health or wellness topics | None / No |
| Gambling (real money) | No |
| Loot boxes | No |
| Unrestricted web access | No (ads open in the system browser or in the App Store sheet, the app itself has no browser) |
| User-generated content | No (documents are private and never shared inside the app) |
| Messaging or chat | No |
| Social media | No |
| Advertising | **Yes** (Google AdMob banners on browse screens and an opt-in rewarded video for export) |
| Parental controls | No |
| Age assurance | No |
| Made for Kids | No. The app is for job seekers. |

Expected result: **4+**. The app limits ad requests to general-audience content (`maxAdContentRating = .general` in `AdsManager`), which matches 4+. Also set the AdMob blocking controls (see `submission-checklist.md` 3.6) so that sensitive ad categories are blocked.

## URLs

| Field | Value |
|---|---|
| Support URL | `https://ecomswiftllc.github.io/careerkit/support/` |
| Marketing URL | `https://ecomswiftllc.github.io/careerkit/` |
| Privacy Policy URL | `https://ecomswiftllc.github.io/careerkit/privacy/` |
| Terms of use (Custom EULA field or link in description) | `https://ecomswiftllc.github.io/careerkit/terms/` |

The static site in `website/careerkit/` is built for exactly these paths. The URLs must return 200 before submission.

**Marketing URL and app-ads.txt.** AdMob reads `app-ads.txt` from the root of the host in the Marketing URL (or the developer website). A GitHub project page (`ecomswiftllc.github.io/careerkit/`) does not let you control the host root, so `https://ecomswiftllc.github.io/app-ads.txt` cannot be served from the project repo. Recommended: set the Marketing URL to `https://www.ecomswiftllc.com` if the owner controls that domain, and serve `https://www.ecomswiftllc.com/app-ads.txt`. Otherwise publish a user-site repo `EcomswiftLLC/ecomswiftllc.github.io` with `app-ads.txt` at its root. The file content is exactly one line:

```
google.com, pub-8621573128492952, DIRECT, f08c47fec0942fa0
```

## Copyright

```
2026 Ecom Swift LLC
```

## Other App Information

| Field | Value |
|---|---|
| SKU | `careerkit-ios` |
| Price | Free (Tier 0) |
| Availability | All regions, but see the EU trader note in `submission-checklist.md` |
| Content rights | No third-party content. Fonts are the ones that ship with iOS. |
| Uses encryption | `ITSAppUsesNonExemptEncryption` is already `false` in Info.plist (standard system HTTPS only) |
| Sign-in required | No |
| Device families | iPhone and iPad (`TARGETED_DEVICE_FAMILY` 1,2) |
| Minimum iOS | 17.0 |

## Review notes for Apple

```
Thank you for reviewing CareerKit. No sign-in or demo account is needed. There is no account system.

What the app does: builds resumes and cover letters on device and exports them as PDF, Word, Rich Text, plain text or web page files. All documents stay on the device.

Ads: the app is free and uses Google AdMob only. There are no purchases and no StoreKit. Two placements exist.
1. A banner on browse screens (Home, My Resumes, Templates, Cover Letters, Profile). Never in the editor or on the preview and export screens.
2. One rewarded video that the user opts into before exporting a finished document. One completed video covers one export of that document. The export is unlocked only after the video has been watched to the end. Creating, editing, previewing, cover letters and the ATS check never show an ad.
There are no interstitial ads and no app-open ads.

Export always works. If no video can be shown (no ad available, offline, ads not allowed by the consent choice, or the video fails to load or start), the export sheet says "No video is available right now, so this export is free." and offers Export without video, which continues straight to Share, Save to Files and Print.

Consent: on first launch the app shows the Google User Messaging Platform consent form where required, then the App Tracking Transparency prompt. Everything stays usable if the user declines both. The Profile tab has an Ad privacy choices row (shown where the consent form requires it) to change the answer, and a Report an ad row.

How to test:
1. Launch the app and finish the five short welcome pages (Skip is available).
2. On Templates, choose any template and create a resume (sample content can be replaced; a Blank resume is also available).
3. Edit any field. The preview updates. No ad is shown while editing.
4. Open the ATS check from the resume to see general guidance. It is not a score from any employer system.
5. Create a cover letter from the Cover Letters tab.
6. Tap Export on a resume. The sheet explains that one short video is needed. Tap Watch an ad to export, let the video finish, pick a file type (PDF, Word, Rich Text, plain text or web page), then choose Share, Save to Files or Print (Print is for PDF).
7. Profile > Delete all local data (two confirmation steps, with an option to export a backup first) removes every resume and letter from the device.

If no rewarded video is available when you test (new ad units can have no fill for the first days, and fill varies by region), the sheet offers Export without video after about 20 seconds at most. Tap it to finish the export.

Contact: support@ecomswiftllc.com
```

## Screenshot plan

Required sizes (portrait): **6.9-inch iPhone 1320 x 2868**, **6.5-inch iPhone 1284 x 2778**, **13-inch iPad 2064 x 2752**. Apple lets the 6.9-inch set stand in for smaller iPhones, so 6.5-inch is only needed if App Store Connect asks for it. Upload up to 10 per size, 8 are planned.

Capture raw simulator screens on a Mac (iPhone 16 Pro Max for 6.9-inch, iPhone 11 Pro Max or 14 Plus for 6.5-inch, iPad Pro 13-inch M4). Drop the raw PNGs into `design/screens-raw/<size>/01.png` to `08.png`, then run `python design/make_store_screenshots.py` to add the caption frame. The captions and layout below are what that script uses.

Rules for every screenshot:
- Real app screens only. No mock data that is not in the app. Use the built-in sample content ("Sample content, fictional person") or a clearly fictional person.
- Banner ads must not be visible and no test-ad labels ("Test Ad") may appear. Capture with the AdMob test ids disabled or crop the banner area by choosing screens where the banner has collapsed.
- Light mode for all eight. Status bar at 9:41 with full battery and signal (Simulator: Features > Status Bar, or `xcrun simctl status_bar booted override --time 9:41`).
- No hands, no device frames, no emoji, no star ratings, no claims about jobs or employers.

| # | Screen | Caption (max 5 words, serif) | Raw screen to capture | Layout notes |
|---|---|---|---|---|
| 1 | Create a professional resume | Build a polished resume | The editor with the live preview showing a filled single-column template | Hero shot. Caption top, preview fills the lower 78 percent and bleeds off the bottom edge. |
| 2 | Explore templates | 30 templates to choose from | The Templates grid with the category chips visible | Show three rows of thumbnails. Keep the banner area collapsed. |
| 3 | Customize every detail | Change every detail | Style panel open (accent colour, fonts, spacing) beside the resume | Pick a template with a clear accent colour so the change is visible. |
| 4 | Build from scratch | Arrange every section | The Blank resume path or a mostly empty resume with the section list | Show the "add section" list so the control is the story. |
| 5 | Matching cover letters | Cover letters that match | A cover letter preview next to its matching resume look (same accent and fonts) | Use the cover letter editor with the preview, same accent colour as shot 1. |
| 6 | ATS check | Check your layout | The ATS check results list with a mix of good and warning findings | The general guidance disclaimer line should be visible in the capture. |
| 7 | Manage multiple resumes | Keep one resume per job | My Resumes list with three or four documents, one with a progress ring | Titles such as "Product Designer" and "Teaching Roles" are fine. |
| 8 | Export PDF | Share or save as PDF | The export sheet with the Share, Save to Files and Print options | Capture after a completed reward, never during or before an ad. |

Frame spec used by the script: ivory `#FAF7F0` background, caption in a serif (Georgia, falling back to DejaVu Serif) in charcoal `#1F2421`, a 4 px champagne `#B89B5E` rule under the caption, the raw capture at 88 percent of the canvas width with rounded corners and a soft shadow.

## App preview storyboard (25 seconds, portrait, no voice-over, no music with vocals)

Record from the Simulator or a device on 6.9-inch size (1320 x 2868, 30 fps, H.264, under 30 s). Show only the app. Do not record ad creatives from third parties: stop recording before the rewarded video starts and resume on the export options.

| Time | Scene | On-screen caption (optional, serif) |
|---|---|---|
| 0:00 to 0:04 | Templates grid scrolls slowly, one template is tapped | 30 templates |
| 0:04 to 0:10 | Editor: a name and a job title are typed, the live preview updates | Type, and the page follows |
| 0:10 to 0:14 | Style panel: accent colour and font are changed | Change every detail |
| 0:14 to 0:18 | Cover Letters: a letter is created with the matching look | A cover letter to match |
| 0:18 to 0:22 | ATS check list scrolls | General guidance, no scores |
| 0:22 to 0:25 | Export sheet with Share, Files and Print, then the app icon on ivory | Share, save or print |

No caption may mention price ("free", "with ads" or similar): Apple guideline 2.3.7 keeps prices out of screenshots and previews.

## Icon concepts note

The shipped icon is "Folded Ascent": a champagne folded page corner and a rising champagne stroke that together form a K on a forest-green field. The stroke sits at the same 45 degree angle as the fold and points at it. Light, dark and tinted 1024 px versions are in `Sources/Resources/Assets.xcassets/AppIcon.appiconset/`. The generator is `design/make_icon.py` and the reasoning is in `design/icon-philosophy.md`.

Concepts considered and set aside:
1. A "C" arc with a rising stroke through its opening. Closer to a generic growth or analytics mark.
2. A page with greyed text lines of ascending length. Too close to every document icon.
3. A tall folded-corner page with no letter. Cleaner, but not ownable.

Known limit: the K on a page can read as a file icon at very small sizes. The fold and the champagne arm are what separate it from the system document glyph. Check it on a real home screen at 60 pt before launch.
