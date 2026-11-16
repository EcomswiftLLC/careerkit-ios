# App privacy (App Store Connect "App Privacy" answers), DRAFT

Status: draft. The data table below matches the ads owner's questionnaire in `docs/handoff/ads.md` (same rows, same linked and tracking answers). If the ads owner changes `PrivacyInfo.xcprivacy` or the ATT flow, update both files together. Google's own page "Apple's App privacy details" for the Mobile Ads SDK is the source of truth for what the SDK collects and changes between SDK versions, so re-check it against the SDK version that ships (`from: 12.0.0` in `project.yml`).

## What the app itself does with data

| Data | Where it goes |
|---|---|
| Resume and cover letter content (name, contact details, work history, education, skills, optional photo) | Stored on the device only, in the app's own storage. Never sent to Ecom Swift LLC or anyone else. Not collected. |
| Photo chosen for a resume | Read through the system photo picker, downsized, stored inside the resume on the device. Not collected. |
| PDF exports and backup files | Created on the device and handed to the share sheet, Files or Print. The user decides where they go. Not collected. |
| Account data | None. There is no account. |
| Analytics, crash reporting | None from the app. No analytics SDK. |
| Purchases | None. No StoreKit. |

Because Ecom Swift LLC receives none of the above, the first question "Do you or your third-party partners collect data from this app?" is answered **Yes**, but only because of the advertising SDK described next.

## Data collected by the Google Mobile Ads SDK (third party, AdMob)

Declare these data types. The purposes are listed per row. The app does not use any of this data for its own analytics or features.

| Apple category | Data type | Collected | Linked to the user | Used to track | Purposes |
|---|---|---|---|---|---|
| Identifiers | Device ID (IDFA when the user allows tracking, otherwise limited identifiers) | Yes | Yes | Yes (only after ATT consent) | Third-Party Advertising |
| Usage Data | Advertising Data (ad impressions, taps, ad load results) | Yes | Yes | Yes (only after ATT consent) | Third-Party Advertising |
| Usage Data | Product Interaction (taps and interaction with ads) | Yes | Yes | No | Third-Party Advertising |
| Location | Coarse Location (approximate, derived from IP address) | Yes | No | No | Third-Party Advertising |
| Diagnostics | Performance Data | Yes | Yes | No | Third-Party Advertising, Analytics |
| Diagnostics | Crash Data | Yes | No | No | Analytics |

Notes for the person filling in the form:
- "Linked to the user" and "tracking" are conservative here. Apple treats an advertising identifier used for advertising as linked and as tracking. If Google's current page says otherwise for the SDK version in use, follow Google's page.
- Tracking domains: leave to what the Xcode privacy report shows after a build. Do not invent a list.
- No data type is collected for "App Functionality", "Analytics" or "Product Personalization" by the app itself.
- Contact info, health, financial info, contacts, user content, search history, browsing history, sensitive info and purchases: **Not collected**.

## Privacy nutrition label summary (what shows on the App Store)

- Data Used to Track You: Identifiers (Device ID), Usage Data (Advertising Data).
- Data Linked to You: Identifiers, Usage Data.
- Data Not Linked to You: Usage Data (Product Interaction), Location (Coarse), Diagnostics.

## Consent flow, as designed

1. First launch, after onboarding: Google User Messaging Platform (UMP) shows the consent form where the user's region requires it (for example the EEA, the UK).
2. After the consent step, the app shows the App Tracking Transparency prompt. The purpose string in Info.plist (`NSUserTrackingUsageDescription`) reads: "Your data is used to show you more relevant ads. You can use CareerKit fully without allowing this."
3. Ads are requested only when UMP says `canRequestAds`. If consent is refused, ads may still appear if the user's region allows non-personalised ads, otherwise the banner collapses and the rewarded video is unavailable (the export flow handles this state, see the ads handoff).
4. The Profile tab has an Ad privacy choices row (shown when UMP says it is required) that reopens the UMP form. If ad consent is required and declined, ads cannot load and export is unavailable (the export sheet explains this).

## Files that must agree with this document

- `Sources/Resources/PrivacyInfo.xcprivacy` (ads owner): tracking = true, collected data types as in the table above. The ads handoff says the tracking domains in it come from general knowledge and must be checked against Xcode's privacy report after the first archive.
- `Sources/Resources/Info.plist`: `NSUserTrackingUsageDescription`, `GADApplicationIdentifier`, `SKAdNetworkItems` (the SDK may need more identifiers than the single one now listed: check Google's current SKAdNetwork list before release).
- `docs/legal/privacy-policy.md` and the website privacy page (same wording about AdMob, UMP and ATT).
- Data deletion: all resume data is deleted in Profile > Delete all local data. Ad identifiers are controlled by iOS (Settings > Privacy & Security > Tracking, and "Reset Advertising Identifier").

## Open questions for the owner

1. Will the owner serve non-personalised ads only? That would remove the tracking answer but also lower revenue. The checklist assumes personalised ads with consent.
2. Confirm the final answers in App Store Connect against the SDK version actually shipped.
