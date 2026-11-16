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
- `Onboarding/OnboardingView.swift`, `OnboardingArt.swift`: five pages, Skip and Get Started, Reduce Motion aware. Art uses real `TemplateThumbnail`s and real font names.
- `Home/HomeView.swift`, `HomeSections.swift`: greeting, create buttons, recent resumes, template carousel, cover letter shortcut, career tools, "How CareerKit stays free", banner last, new-user empty state.
- `MyResumes/MyResumesView.swift`: search, sort, active/archived, list or grid, swipe and context actions, banner at the end of the list, empty states.
- `MyResumes/ResumeActionHost.swift`: rename alert, delete confirmation, change template sheet, toasts. Shared by Home and My Resumes.
- `MyResumes/ResumeSorting.swift`: `CKResumeSort`, `CKResumeSearch`, `CKResumeStats` (pure logic).
- `MyResumes/CompareVersionsView.swift`: two pickers, two real first-page previews, side-by-side counts, full preview sheet.
- `Templates/TemplateBrowserView.swift`, `TemplateFilter.swift`, `TemplatePreviewSheet.swift`, `TemplateFlows.swift`: browser, filters, large preview, "Use This Template" flow, template picker for existing resumes.
- `Profile/ProfileView.swift`, `HowExportsWorkView.swift`, `CKLinks.swift`: settings, backup, two-step delete, explainer, links.

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

- No unit tests were added (this owner has no test directory in the ownership table). Good candidates: `CKTemplateFilter`, `CKResumeSort`, `CKResumeSearch`, `CKResumeStats`, `AppState.suggestedPageSize`.
- Resume thumbnails render on a background task per card; very large libraries may want a concurrency limit.
- No localisation table yet. User-facing strings use `Text` literals, `LocalizedStringKey` or `String(localized:)`, so a catalog can be extracted later.
- VoiceOver, Dynamic Type and Reduce Motion were designed in but not tested on a device.
- The banner ad is placed at the end of scroll content on every screen; its real height depends on the ads owner's view.

## Compile watch list

- `.tabViewStyle(.sidebarAdaptable)` and `Tab(...)` need the Xcode 16 SDK.
- `CKAppearance` uses `#available(iOS 26, *)`; on an older Xcode the check should still compile.
- Generic closures passed to `CKFilterChipBar`, `CKFilterMenuChip` and `CKAdaptiveGrid` carry explicit parameter types to help inference.
- Views that call `@MainActor` store APIs rely on the `@EnvironmentObject` wrapper for actor inference.
