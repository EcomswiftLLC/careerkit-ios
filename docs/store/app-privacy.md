# App privacy (App Store Connect "App Privacy" answers)

These are the exact answers to enter in App Store Connect > App Privacy. `Sources/Resources/PrivacyInfo.xcprivacy` declares the same data types with the same linked and tracking flags. If one changes, change both. Google's page "Apple's App privacy details" for the Mobile Ads SDK is the source of truth for what the SDK collects; re-check it against the SDK version that ships (`from: 12.0.0` in `project.yml`) before each submission.

## What the app itself does with data

| Data | Where it goes |
|---|---|
| Resume and cover letter content (name, contact details, work history, education, skills, optional photo) | Stored on the device only, in the app's own storage. Never sent to Ecom Swift LLC or anyone else. Not collected. |
| Photo chosen for a resume | Read through the system photo picker, downsized, stored inside the resume on the device. Not collected. |
| Exported files (PDF, Word, Rich Text, plain text, web page), imported PDFs and backup files | Created or read on the device and handed to the share sheet, Files or Print. The user decides where they go. Not collected. |
| Optional writing help (iOS 26 or later with Apple Intelligence) | Text the person chooses to improve is processed by Apple's on-device model and never leaves the device; it is not sent to Ecom Swift LLC, Apple or anyone else. Not collected. |
| Export unlock record | A document id and a time, stored on the device only, used to allow one export. Not collected. |
| Account data | None. There is no account. |
| Analytics, crash reporting | None from the app. No analytics SDK. |
| Purchases | None. No StoreKit. |

"Do you or your third-party partners collect data from this app?" **Yes**, only because of the Google Mobile Ads SDK (AdMob) and Google's User Messaging Platform.

## The answers (enter exactly these)

| Apple category | Data type | Linked to the user | Used for tracking | Purposes |
|---|---|---|---|---|
| Identifiers | Device ID | Yes | Yes | Third-Party Advertising, Analytics |
| Usage Data | Advertising Data | Yes | Yes | Third-Party Advertising |
| Usage Data | Product Interaction | Yes | No | Third-Party Advertising |
| Location | Coarse Location | No | No | Third-Party Advertising |
| Diagnostics | Performance Data | Yes | No | Third-Party Advertising, Analytics |
| Diagnostics | Crash Data | No | No | Analytics |

Every other data type is **Not collected**: Contact Info, Health and Fitness, Financial Info, Precise Location, Sensitive Info, Contacts, User Content, Browsing History, Search History, Purchases, Other Identifiers (User ID), Other Usage Data, Other Diagnostic Data, Other Data.

"Do you or your third-party partners use data for tracking purposes?" **Yes** (Device ID and Advertising Data, by AdMob, only after the person allows tracking in the ATT prompt).

## Privacy nutrition label (what the App Store will show)

- **Data Used to Track You:** Identifiers (Device ID), Usage Data (Advertising Data).
- **Data Linked to You:** Identifiers (Device ID), Usage Data (Advertising Data, Product Interaction), Diagnostics (Performance Data).
- **Data Not Linked to You:** Location (Coarse Location), Diagnostics (Crash Data).

## Privacy manifest notes

- `NSPrivacyTracking` is `true`. The collected data types match the table above.
- `NSPrivacyTrackingDomains` is **not declared**. iOS blocks requests to declared tracking domains for people who deny ATT, and the earlier entries were written from memory, not taken from the SDK. The Google Mobile Ads SDK ships its own privacy manifest. After the first archive, open Xcode's privacy report (Organizer > Archive > Generate Privacy Report) to see the merged result. Do not add domains by hand.
- Required-reason APIs declared by the app: UserDefaults `CA92.1`, file timestamp `C617.1`.

## Consent flow, as built

1. First launch, after onboarding: Google User Messaging Platform (UMP) shows the consent form where the person's region requires it (for example the EEA and the UK).
2. After the consent step, and only if consent allows ads, iOS shows the App Tracking Transparency prompt. The purpose string in Info.plist (`NSUserTrackingUsageDescription`) reads: "Your data is used to show you more relevant ads. You can use CareerKit fully without allowing this."
3. Ads are requested only when UMP says `canRequestAds` and the SDK has started. Ad requests are limited to general-audience content (`maxAdContentRating = .general`). Child-directed tags are not set: the app is not directed to children.
4. If consent does not allow ads, no banner appears. Export still works: when the person asks for a video and none can play, the export sheet offers "Export without video" for that one export.
5. The Profile tab has an Ad privacy choices row (shown where UMP says it is required) that reopens the UMP form, and a "Report an ad" row that writes to support.

## Files that must agree with this document

- `Sources/Resources/PrivacyInfo.xcprivacy` (same rows, linked and tracking flags, no tracking domains).
- `Sources/Resources/Info.plist`: `NSUserTrackingUsageDescription`, `GADApplicationIdentifier`, `SKAdNetworkItems` (Google's list of 50 SKAdNetwork ids, fetched 2026-11-16; re-check Google's current list before each release).
- `docs/legal/privacy-policy.md` and the website privacy page (same wording about AdMob, UMP, ATT and the export without video).
- Data deletion: all resume data is deleted in Profile > Delete all local data. Ad identifiers are controlled by iOS (Settings > Privacy & Security > Tracking, and "Reset Advertising Identifier").
