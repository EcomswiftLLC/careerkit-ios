# Export gate (iOS): what the owner must create in App Store Connect

Owner order 2026-11-17: everything a person takes out of CareerKit (Share, Save to Files, Print, in PDF, Word, Rich Text, plain text and web page) uses one export. Editing, previewing, drafts, the ATS check and templates stay free.

## How it works in the app

| Situation | What happens |
|---|---|
| Premium active | Export goes ahead, nothing is used up. |
| A completed rewarded video for this document (valid 24 hours) | Export goes ahead, the video unlock is used up. |
| Exports left from an export pack | Export goes ahead, one export is used up. |
| None of the above | The export sheet shows the choices: 3 exports, Premium, watch a short video, Restore purchases. |
| No video can play | The sheet says why. Nothing is unlocked. The person can try again or use a pack or Premium. |
| App Store not reachable (error, or no answer within 15 seconds) | The sheet says prices are not available and offers Try again. Nothing is unlocked, nothing is charged. |
| **App Store reachable but has none of our products** (`CatalogState.noProducts`: products not created, not Ready to Submit, or not sold in this region) | The sheet says "Purchases are not available right now" and offers Try again. It shows no pack, no Premium and no Restore purchases, and the Home, onboarding, Profile and "How exports work" texts stop mentioning purchases. The video option stays. If no video can play (or no video is configured), **Export without video** is offered for that one export, as in version 1.0. |

- **Why the free path exists, and only here.** With no products there is nothing to buy, so a video that cannot play would leave the person with no way to export (a dead end for App Review, where new ad units often have no fill). `ExportStore.allowsExportWithoutVideo` is true only for `.noProducts`. An unreachable store, a timeout or an empty/loading state never opens it, so a person with a bad connection cannot skip the gate. The decision is `ExportStore.catalogState`, covered by `ExportStoreTests`.
- Prices are fetched again every time the export sheet opens without prices, and a price request that does not answer within 15 seconds becomes "not reachable" (a late answer is still used, a newer request is never overwritten by an older one).
- A video that starts after the 6 second "did not start" watchdog already answered is still counted: when it is watched to the end, `RewardedAdController.lateRewardCount` goes up and the sheet grants the export.
- An export is used up only after the system reports that the file was really shared, saved to Files or printed. Closing the share sheet, cancelling Files or a print error use nothing (`ExportStore.settle`).
- Order of use: Premium, then the video unlock, then a pack export.
- A purchase adds exports only after StoreKit verified it. Pending (Ask to Buy), cancelled, failed and unverified purchases add nothing. The transaction is saved before it is finished, and each transaction id is applied once. A refund takes the 3 exports back once, never below zero.
- Exports from packs are kept in the Keychain (with a UserDefaults copy), so they survive deleting and reinstalling the app. "Delete all local data" in Profile does not remove purchases.
- Premium comes from `Transaction.currentEntitlements` and is refreshed at launch, after a purchase and on Restore purchases (sheet and Profile). Used-up packs cannot be restored (consumables).
- Restore purchases when nothing is found says "Export packs are used up and cannot be restored" only when no exports are left; otherwise it says the remaining exports are kept on the device.
- Price text always comes from StoreKit (`displayPrice`). There is no price in code.
- Local testing on a Mac: `Config/StoreKit/Configuration.storekit` defines the two products. In Xcode choose Product > Scheme > Edit Scheme > Run > Options > StoreKit Configuration and pick it. It is **not** referenced by the project, the Release scheme or any bundle, and was written by hand without Xcode (open it once in Xcode to confirm it loads). There is no `SKTestSession` unit test because it could not be run here and a failing or hanging test would block CI; add one on a Mac.
- Code: `Sources/Purchases` (StoreKit 2, pure logic, storage, paywall view), `Sources/Ads/ExportFlowSheet.swift` (the sheet), Profile row "Your exports" and "Restore purchases". Unit tests: `Tests/ExportEntitlementTests.swift`.

### Paths that are gated

- Resume editor, Export button (Share, Save to Files, Print, all five file types).
- Resume preview screen, Export button (same sheet).
- Cover letter editor, Export button (same sheet).

### Paths that are deliberately not gated (owner decision needed)

- **Profile > Export backup** and **Export unreadable files**. This is the person's own data safety copy, not a finished document, and locking it behind a payment is a poor idea (and a review risk). One line in `ProfileView.exportBackup()` would gate it if you want that.
- **ATS check > Copy text** copies diagnostic text to the clipboard. Not gated.

## Products to create (App Store Connect > the app > Monetization > In-App Purchases)

Product ids must match exactly.

### 1. Export pack

| Field | Value |
|---|---|
| Type | Consumable |
| Reference Name | Export Pack 3 |
| Product ID | `export_pack_3` |
| Price | USD 0.99 (price point "Tier 1", base country United States, let Apple convert the rest) |
| Availability | All regions the app is sold in |
| Family Sharing | Off (not available for consumables) |

Localizations (Display Name up to 30 characters, Description up to 45):

| Language | Display Name | Description |
|---|---|---|
| English (U.S.) | 3 Exports | Save, share or print 3 documents |
| Spanish | 3 exportaciones | Guarda, comparte o imprime 3 documentos |
| French | 3 exports | Enregistrez ou partagez 3 documents |
| German | 3 Exporte | 3 Dokumente speichern, teilen, drucken |
| Chinese (Simplified) | 3 次导出 | 保存、共享或打印 3 份文档 |

### 2. Premium

| Field | Value |
|---|---|
| Type | Non-Consumable |
| Reference Name | Premium Unlimited Exports |
| Product ID | `premium_unlimited` |
| Price | Your choice. Suggested USD 9.99 (the app shows whatever you set, so it can be changed later without a build). |
| Family Sharing | Optional. Off is fine. |

Localizations:

| Language | Display Name | Description |
|---|---|---|
| English (U.S.) | Premium | Unlimited exports, one purchase |
| Spanish | Premium | Exportaciones ilimitadas, un pago |
| French | Premium | Exports illimités, un seul achat |
| German | Premium | Unbegrenzte Exporte, ein Kauf |
| Chinese (Simplified) | Premium | 不限次数导出，一次购买 |

### For both products

- **Review screenshot** (required): use the CI screenshot of the export sheet, `70-export-paywall.png` from the `screenshots` artifact of the latest green run (sample prices shown in the screenshot are test values, they are not shipped). iPhone size is fine.
- **Review notes**: "Open any resume, tap Export. The sheet offers 3 exports and Premium. Purchases use the sandbox. Restore purchases is on this sheet and in Profile."
- Both products need status **Ready to Submit** and must be added to the app version on the version page ("In-App Purchases and Subscriptions" section) when you submit it. The first in-app purchases of an app must go in with an app version.

## What remains for the owner

1. **Paid Apps Agreement, bank account and tax forms.** The earlier checklist said these were not needed because the app was free. With in-app purchases they are required before products can be sold or reviewed. (Tax answers: see the open W-8BEN question in the CareerKit notes.)
2. Create the two products above and attach them to the next app version.
3. **Version.** CareerKit 1.0.0 (build 11) is in review without StoreKit. `project.yml` is already at `MARKETING_VERSION` 1.1.0, so the gate ships as 1.1.0 with a new build from `release.yml`. Do not wait for 1.0.0 to finish to start; products can be created now. Until the products exist and are attached to the version, the app behaves as described in the "no products" row above.
4. Test with a sandbox Apple Account on TestFlight: buy 3 exports, cancel a share sheet (count must stay), finish an export (count drops by 1), buy Premium, delete and reinstall, tap Restore purchases, test Ask to Buy and a refund if possible. None of this could be run here (no Mac, no device); CI only compiles and runs unit tests.
5. **Copy outside the app that says "no purchases".** The 1.1 wording is now written in the repository (nothing is published): `docs/store/metadata.md`, `docs/store/metadata-localized.md`, `docs/store/submission-checklist.md`, `docs/store/app-privacy.md`, `docs/legal/next-1.1/` (terms and privacy policy), `README.md`, `docs/handoff/ads.md`, and the website draft (`CAREERKIT_EDITION=1.1 python website/build_site.py` writes `website/draft-1.1/careerkit/`, the live `website/careerkit/` stays on the 1.0 text). The 1.0 listing text is kept in `docs/store/v1.0-in-review/`. Paste and publish them only when 1.1 is released. Where each item used to live:
   - `docs/store/metadata.md` and `docs/store/metadata-localized.md` (description, App Review notes: "There are no purchases and no StoreKit", "Export without video").
   - `docs/store/submission-checklist.md` (banking and tax "not needed", review risk 3.9 about the free export without a video).
   - `docs/store/app-privacy.md` (check the purchase answers: Apple's "Purchases" data type is only collected if you keep purchase history yourself, which the app does not).
   - `docs/legal/terms-of-use.md` ("There is no subscription and no in-app purchase") and `docs/legal/privacy-policy.md` (the paragraph about the free export when no video is available).
   - The website pages in `website/build_site.py` (FAQ: "no in-app purchase and no paid version", "export without a video", home page text), then rebuild and publish `EcomswiftLLC/careerkit`.
   - The App Store listing text and screenshots that show the old export sheet.
   - `README.md` and `docs/handoff/ads.md` still describe the free export.
6. Age rating questionnaire: answer that the app now has in-app purchases (no change in rating expected).
7. Decide the Premium price and whether Export backup should also be gated (see above).
8. The reward unlock still allows one export per document for 24 hours. Premium does not remove ads (banners stay, as ordered).
