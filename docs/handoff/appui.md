# appui handoff

Nothing here was compiled or run. There is no Mac on this machine, so every file was written against the contract and the lead files only. Expect a first CI pass to turn up a few small compile errors. The riskiest spots are listed under "Compile watch list".

## Files

App shell, `Sources/App/`
- `CareerKitApp.swift`: `@main`. Creates `DocumentStore`, `AppState`, `ExportGate`, uses `AdsManager.shared`, injects all four, applies the appearance preference and the forest tint. `CKRootContainer` switches between onboarding and tabs, calls `await AdsManager.shared.start()` about 0.4 s after the first frame and only once onboarding is done, and calls `store.flushNow()` on `.background` and `.inactive`.
- `AppState.swift`: `hasCompletedOnboarding`, `defaultPageSize`, `appearance` (`AppearancePreference`: system, light, dark), plus `displayName` (optional local name) and `selectedTab` (not persisted, lets any screen switch tabs). UserDefaults backed. Default paper size is US Letter in US, CA, MX and a few other regions, A4 elsewhere.
- `AppRoute.swift`: pushed destinations (`editor`, `preview`, `atsCheck`, `howExportsWork`) and `.appRouteDestinations()`. Editor, preview and ATS destinations hide the tab bar.
- `RootTabView.swift`: five tabs. iOS 18 uses `Tab` plus `.tabViewStyle(.sidebarAdaptable)`; iOS 17 uses `.tabItem`. `CKTabConfig.wrapCoverLettersInStack` controls whether Cover Letters gets a `NavigationStack` from this file.
- `CKAppearance.swift`: serif navigation titles, ivory bars with hairline edges (system material kept on iOS 26).

Design system, `Sources/DesignSystem/`
- `ComponentsCommon.swift`: `CKSectionHeader`, `CKEmptyState`, `CKPaperSheet` / `CKPaperGlyph` / `CKPaperStack` (drawn artwork), `ckToast`, `CKShareSheet`, `ckTitle` / `ckHeadline` (Dynamic Type aware serif), `CKHairline`, `CKDate`, `CKDeferred`, width-measuring helper.
- `ComponentsResume.swift`: `CKResumeThumbnail` (renders the person's own resume through `DocumentRenderer`, cached), `CKResumeActions`, `CKResumeActionMenu`, `CKResumeTile`, `CKResumeRow`, `CKPageImages` (PDF to images).
- `ComponentsTemplates.swift`: `CKAdaptiveGrid`, `CKTemplateCard`, `CKATSBadge`, `CKFilterChipBar`, `CKFilterMenuChip`, `CKToggleChip`.

Features
- `Onboarding/OnboardingView.swift`, `OnboardingArt.swift`: five pages, Skip and Get started, Reduce Motion aware. Art uses real `TemplateThumbnail`s and real font names.
- `Home/HomeView.swift`, `HomeSections.swift`: greeting, create buttons, recent resumes, template carousel, cover letter shortcut, career tools, "How CareerKit stays free", banner last, new-user empty state.
- `MyResumes/MyResumesView.swift`: search, sort, active/archived, list or grid, swipe and context actions, banner at the end of the list, empty states.
- `MyResumes/ResumeActionHost.swift`: rename alert, delete confirmation, change template sheet, toasts. Shared by Home and My Resumes.
- `MyResumes/ResumeSorting.swift`: `CKResumeSort`, `CKResumeSearch`, `CKResumeStats` (pure logic).
- `MyResumes/CompareVersionsView.swift`: two pickers, two real first-page previews, side-by-side counts, full preview sheet.
- `Templates/TemplateBrowserView.swift`, `TemplateFilter.swift`, `TemplatePreviewSheet.swift`, `TemplateFlows.swift`: browser, filters, large preview, "Use this template" flow, template picker for existing resumes.
- `Profile/ProfileView.swift`, `HowExportsWorkView.swift`, `CKLinks.swift`: settings, backup, two-step delete, explainer, links.

## Audit fixes, 2026-11-16 (app shell, persistence, Profile)

Still not compiled here (no Mac). New and changed files:

- `Sources/Models/ModelDecoding.swift` (new): tolerant `init(from:)` for `Resume`, `PersonalInfo`, `ResumeSection`, `ResumeEntry`, `SkillGroup`, `MonthYear`, `CoverLetter`, plus `SectionKind` (unknown raw value becomes `.custom`, title and content kept). Helpers: `CKCodingKey`, `KeyedDecodingContainer.ck(_:_:)`, `ckOptional(_:as:)`, `ckLossyArray(_:of:)` (one bad array item is skipped, the rest kept). Encoding is untouched: the compiler-generated `encode(to:)` and keys stay, so files look exactly as before. `StyleOverrides` keeps its own decoder. Also `CKPersistedDocument` (shared shape of resumes and letters) and `Date.ckWholeSeconds`.
- `Sources/Persistence/SchemaMigration.swift` (new): `CKSchema.current` (non-isolated; `DocumentStore.currentSchemaVersion` returns it), `CKJSON` encoder/decoder, `CKSchemaPeek`, `CKSchemaMigration.migrate(_:)` step hook.
- `Sources/Persistence/BackupRestore.swift` (new): `CKBackupPayload` (same keys as before, tolerant), `CKBackupParser` (empty, 150 MB cap, format, newer version, security-scoped file read), `CKBackupMerge` (pure merge by id), `CKRestoreSummary`, `CKDocumentNaming` ("X copy", "X copy 2", "X (restored)").
- `Sources/Persistence/TempFileCleanup.swift` (new): `CKTempFiles` removes `CareerKitExport-*` and `CareerKit-Backup-*` in tmp. Stale (older than 1 hour) at launch, everything on delete-all.
- `Sources/Persistence/DocumentStore.swift`: newer-schema files are never decoded, rewritten or quarantined (`newerVersionFileCount`); `quarantinedFiles`, `refreshQuarantine()`, `deleteQuarantinedFiles()`; `restoreBackup(from:)`; the file name UUID wins when the id inside is missing; a failed quarantine move no longer deletes the file; numbered copy titles.
- `Sources/App/LocalDataReset.swift` (new): `CKLocalDataReset.eraseEverything(store:exportGate:appState:)` and `Notification.Name.ckCachesShouldClear`.
- `Sources/App/AppState.swift`: `dataResetGeneration` + `resetNavigation()`. `RootTabView` uses it as `.id` on Home, My Resumes, Templates and Cover Letters (Profile keeps its identity so its toast stays).
- `Sources/App/CareerKitApp.swift`: background temp cleanup task at launch.
- `Sources/App/AppRoute.swift`: `.preview` now shows `ResumePreviewScreen` (new, `Features/MyResumes/`), which adds an Export button that opens `ExportFlowSheet`.
- `Sources/Features/Profile/ProfileView.swift`: Restore from backup (`.fileImporter`, JSON), result alert ("Restored N documents, skipped M."), unreadable files row (export via share sheet, delete with confirmation), newer-version row, Report an ad (mailto, subject "Ad report"), `CKInlineBanner(slot:)`, backup temp file removed when the share sheet closes. `CKSettingsRow` moved to `CKSettingsRow.swift` (adds `isBusy`).
- `Sources/Features/ATS/ATSCheckView.swift`: info icon uses forest instead of champagne (contrast).
- Tests: `Tests/PersistenceDecodingTests.swift`, `Tests/PersistenceBackupTests.swift`, `Tests/AppShellTests.swift`.

Delete all local data now clears: documents and `.bak` copies, Quarantine, newer-version files, every ExportGate grant (via `forget`), `CareerKitExport-*` and `CareerKit-Backup-*` temp items, the local name, and posts `ckCachesShouldClear`, then rebuilds the browse tabs.

For the Preview and DesignSystem owner: please observe `Notification.Name.ckCachesShouldClear` (posted on the main thread) and empty `CKImageCache` and `ThumbnailRenderer.cache`. `CKImageCache` has no public clear method yet, so this module cannot clear it directly.

Restore rules (`CKBackupMerge`): same id and same content is skipped; a newer backup version replaces the device copy; when the device copy is newer (or the same second with different content) both are kept, and the backup copy gets a new id and "(restored)" in its title. Ids of newer-version files are never reused. Timestamps are compared in whole seconds because JSON keeps whole seconds.

## Contract APIs relied on

`DocumentStore` (resumes, coverLetters, resume(id:), upsert, delete, duplicate, setArchived, flushNow, deleteAllData, makeBackupFile), `ExportGate` (injected only), `AdsManager.shared` (start, presentPrivacyOptions, privacyOptionsRequired), `BannerAdView()`, `DocumentRenderer.render`, `TemplateLibrary` (all, spec(id:), defaultTemplateID), `SampleContent` (resume(for:), sampleLabel), `ResumeEditorView(resumeID:)`, `ResumePreviewView(resumeID:)`, `NewResumeFlow(templateID:onCreated:)`, `CoverLetterListView()`, `ATSCheckView(resumeID:)`, `TemplateThumbnail(template:size:)`.

## Assumptions to confirm with the other owners

1. `TemplateThumbnail(template:size:)`: I treat `size` as the width and frame it at width x width * 1.414 (A4).
2. `NewResumeFlow` presents inside a sheet and reads the default paper size from the `AppState` environment object. It should not dismiss itself before calling `onCreated`; I close the sheet myself.
3. `CoverLetterListView` has no `NavigationStack` of its own. If it has one, set `CKTabConfig.wrapCoverLettersInStack = false`.
4. `ResumePreviewView` has no navigation chrome of its own; Compare wraps it in a `NavigationStack` with a Done button.
5. `DocumentStore.duplicate(resumeID:)` returns the copy and `upsert` accepts a changed resume (used for rename and change template).
6. `ExportGate.consume` timing and the export flow itself belong to the ads and editor owners. This module never shows an export button.

## Deviations and decisions

- Rate the app: `SKStoreReviewController` lives in StoreKit, and the contract says never import StoreKit. The row opens the App Store write-review page when Info.plist has a `CKAppStoreID` string, and the product page `https://ecomswiftllc.github.io/careerkit` otherwise. The lead can add the key later. No prompt appears without a tap.
- Onboarding says "no account" and "documents stay on this device" but does not claim "no data collected", because AdMob uses consent-based identifiers. The last page states the required free model sentence and a short AdMob consent note.
- Extra route `howExportsWork` and extra `AppState` members (`displayName`, `selectedTab`) are additions, not changes.
- Category summaries in the template browser are written from the category names, not from template contents.

## Known gaps

- Unit tests now cover `CKResumeSort`, `CKResumeSearch`, `AppState.suggestedPageSize`, backup merge, tolerant decoding and temp cleanup. Still untested: `CKTemplateFilter`, `CKResumeStats`.
- Resume thumbnails render on a background task per card; very large libraries may want a concurrency limit.
- No localisation table yet. User-facing strings use `Text` literals, `LocalizedStringKey` or `String(localized:)`, so a catalog can be extracted later.
- VoiceOver, Dynamic Type and Reduce Motion were designed in but not tested on a device.
- The banner ad is placed at the end of scroll content on every screen; its real height depends on the ads owner's view.

## Compile watch list

- `.tabViewStyle(.sidebarAdaptable)` and `Tab(...)` need the Xcode 16 SDK.
- `CKAppearance` uses `#available(iOS 26, *)`; on an older Xcode the check should still compile.
- Generic closures passed to `CKFilterChipBar`, `CKFilterMenuChip` and `CKAdaptiveGrid` carry explicit parameter types to help inference.
- Views that call `@MainActor` store APIs rely on the `@EnvironmentObject` wrapper for actor inference.
- Model decoders are `init(from:)` in extensions in `ModelDecoding.swift`, a different file from the type declarations. This is a supported pattern (explicit witness, memberwise initialisers kept). If CI complains, move each extension into the file of its type.
- `SectionKind.init(from:)` overrides the standard `RawRepresentable` decoding; it must stay a concrete member of `SectionKind`.
- `ckLossyArray` relies on `UnkeyedDecodingContainer.currentIndex` advancing after decoding `CKSkippedValue`; a guard stops the loop if it does not.
- `ProfileView` uses `.fileImporter` and `.alert` on the `NavigationStack` and a second `.alert` / `.confirmationDialog` on the unreadable-files row, so no two presentations share a view.
