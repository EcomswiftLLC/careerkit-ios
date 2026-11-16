# Editor owner handoff

**Nothing in this handoff was compiled or run.** There is no Mac on this machine. Every file was written against the contract in `docs/ARCHITECTURE.md` and checked by reading only. Expect a first CI pass to surface a handful of compiler errors (see "Riskiest compile spots"). The design critique, accessibility and UX copy reviews could not be run on real screenshots for the same reason.

## Public views (contract) and where they live

| View | File | Notes |
|---|---|---|
| `ResumeEditorView(resumeID:)` | `Sources/Features/Editor/ResumeEditorView.swift` | Needs an enclosing NavigationStack. |
| `ResumePreviewView(resumeID:)` | `Sources/Features/Preview/ResumePreviewView.swift` | Needs an enclosing NavigationStack. |
| `PDFPreview(data:)` | `Sources/Features/Preview/PDFPreview.swift` | Optional `controller:` and `accessibilityName:` parameters. |
| `NewResumeFlow(templateID:onCreated:)` | `Sources/Features/Editor/NewResumeFlow.swift` | Has its own NavigationStack: present as a sheet. |
| `CoverLetterListView()` | `Sources/Features/CoverLetters/CoverLetterListView.swift` | Needs an enclosing NavigationStack. Only place with `BannerAdView`. |
| `CoverLetterEditorView(letterID:)` | `Sources/Features/CoverLetters/CoverLetterEditorView.swift` | No ads. |
| `ATSCheckView(resumeID:)` | `Sources/Features/ATS/ATSCheckView.swift` | Needs an enclosing NavigationStack. |
| `TemplateThumbnail(template:size:)` | `Sources/Features/Preview/TemplateThumbnail.swift` | `size` is the thumbnail width in points. Height follows the A4 ratio. |
| `VersionCompareView(leftID:rightID:)` | `Sources/Features/Preview/VersionCompareView.swift` | Needs an enclosing NavigationStack (toolbar button). The shell currently has its own `CompareVersionsView`; either works. |

Extra public helpers other code may reuse: `CoverLetterThumbnail(template:size:)`, `PreviewPane(renderer:)`, `LivePreviewRenderer`, `EdUnavailableView`.

## All files

Editor
- `EditorSupport.swift`: pure logic (`ListEditing`, `SectionOps`, `MonthYearHelper`, `TokenParsing`, `TextInsertion`, `FileNaming`, `EntryLabels`, `StyleLimits`, `PhotoProcessor`).
- `AutosaveDraft.swift`: generic local working copy + autosave + render scheduling.
- `EditorComponents.swift`: `EdField`, `EdTextArea`, `EdDisclosureCard`, `EdTextButton`, `EdMoreMenu`, `EdSaveIndicator`, `EdModeSwitch`, `EdFlowLayout`.
- `ResumeEditorView.swift`, `SectionEditors.swift` (text sections, personal info, dispatcher), `EntryEditors.swift` (entries, dates, bullets), `SkillEditors.swift` (token list, skill groups), `PhotoRow.swift`.
- `SectionManager.swift`, `StylePanel.swift`, `TemplateSwitcherSheet.swift`.
- `WritingExamples.swift` (static library), `WritingExamplesSheet.swift`.
- `NewResumeFlow.swift`, `BlankBuilderView.swift`, `BlankPreview.swift`.

Preview: `LivePreviewRenderer.swift` (also `EditorRender`, `RenderWork`), `PDFPreview.swift`, `PreviewPane.swift`, `ResumePreviewView.swift`, `TemplateThumbnail.swift`, `VersionCompareView.swift`.

CoverLetters: `CoverLetterListView.swift`, `NewCoverLetterSheet.swift`, `CoverLetterEditorView.swift`, `CoverLetterForm.swift` (form + suggestion sheet), `CoverLetterSuggestions.swift` (also `CoverLetterPrefill`), `CoverLetterTemplateSheet.swift`.

ATS: `ATSCheckView.swift` (views only; `ATSAnalyzer.swift` untouched).

Tests: `Tests/EditorSupportTests.swift`, `Tests/EditorContentTests.swift`.

## Behaviour summary

- **Autosave**: `AutosaveDraft` loads once from `DocumentStore`, edits a local copy, calls `store.upsert` on every real change (the store debounces the write), and calls `store.flushNow()` when the editor disappears. `store.saveState` drives the "Saving / Saved / Not saved" line under the title; `.idle` reads "Saved" so the line shows from the moment the editor opens.
- **Stale copies**: `persist` returns false when the store no longer has the id, and nothing is written; the draft drops its copy (`isGone`) and the editor shows "This resume is no longer available" with a Back button. Both editors observe `store.$resumes` / `store.$coverLetters` and call `draft.reconcile(with:adopt:)`: a missing document marks the draft gone (this also covers "Delete all data", which empties the arrays), and `DraftAdoption.adopt` copies title, templateID and isArchived (letters: title, templateID) from the store copy without writing back. A deleted document is never re-created from a stale draft. No separate data-reset notification is needed for this; if worker B adds one, observing it is optional.
- **Live preview**: every change schedules a render 0.35 s later (debounce, the newest request wins). A synchronous render cannot be stopped, so `LivePreviewRenderer` keeps at most one render in flight and one pending: requests that arrive while a render runs replace the single pending one, which starts when the running render ends (pure state machine `PreviewRenderQueue`, unit tested). `cancel()` drops waiting work and ignores the running result. The previous PDF stays visible, a small "Updating" badge shows while busy. `PDFPreview` keeps page and zoom when a new PDF arrives. Never renders on the main thread (the export sheet's `renderedProvider` is the only synchronous render, as the contract requires a sync closure).
- **Compact layout**: Edit / Preview switch. Opening Template or Style jumps to Preview so the half-height sheet shows the effect. On regular width (iPad) edit and preview sit side by side.
- **Thumbnails**: every thumbnail (template, letter and the person's own resume cards in `CKResumeThumbnail`) renders through the serial `ThumbnailRenderer.shared` actor, so one render runs at a time and requests from cells that left the screen are skipped. Template cache: 90 items / 40 MB decoded. Resume card cache (`CKImageCache`): one entry per resume and size (no edit date in the key), 60 items / 32 MB; each entry stores a content fingerprint (`CKResumeFingerprint`, edit dates and archive flag excluded), so unchanged resumes never re-render and an edited one re-renders once, 0.7 s after edits settle, with the old image shown meanwhile. Both caches empty on the `CKCachesShouldClear` notification (`CKCacheClearing.register`, also `ThumbnailRenderer.clearCache()` and `CKImageCache.shared.removeAll()`).
- **Photo**: `PhotoProcessor.process` uses ImageIO (`CGImageSourceCreateThumbnailAtIndex`, max 800 px, EXIF orientation applied, decoded straight to size), flattens onto white and writes JPEG at 0.85. Files over 150 MB or 200 megapixels, and unreadable data, return a plain error shown under the photo. The row preview also decodes a thumbnail only. "Remove photo" shows an inline "Photo removed" bar with Undo (and a VoiceOver announcement).
- **Blank builder**: a draft resume is held in memory (not stored) until "Create resume". Preview fills empty parts with sample text (`BlankPreviewMapper`, preview only). Safeguards: `StyleLimits.blank` (margin 28...72 pt, text scale 0.9...1.1, line spacing 0.95...1.3), re-applied on create.
- **Cover letters**: linking a resume copies only empty sender fields; "Replace sender details" overwrites after a confirmation. If the linked resume's template has a paired letter template (`matchingResumeTemplateID`), a banner offers to switch and copy accent and fonts.

## Deviations and decisions to know about

1. `TemplateThumbnail.size` is treated as the **width**, height = width x 1.4142. The shell already passes widths.
2. `NewResumeFlow` calls `onCreated(id)` first and then `dismiss()` on its own environment. The shell's own `isPresented = false` makes the second dismiss a no-op.
3. All pushed views (editor, preview, ATS, cover letter list and editor, compare) assume an enclosing `NavigationStack`, which the shell provides. They hide the tab bar themselves where they have a bottom toolbar.
4. The editor and cover letter editor use `.bottomBar` toolbar items (Template, Style, Sections, ATS check). They do not show the tab bar or any ad.
5. Writing examples use US spelling and say plainly that figures are examples to be replaced.
6. ATS check shows the engine's `report.disclaimer` after the run and a fixed honest sentence while running. No numeric score is shown.
7. `ATSCheckView` reads the resume from `DocumentStore` (not from the editor's local copy). This relies on `upsert` updating `store.resumes` synchronously, which the contract implies.
8. Entry reorder, bullet reorder, skill group reorder and token reorder use Move up / Move down menu items (accessible and reliable inside a ScrollView). Section reorder uses real drag handles (List in edit mode).

## Assumptions about other owners' APIs

- `AppState.defaultPageSize: PageSize` (verified in `Sources/App/AppState.swift`).
- `ResumeFactory.newCoverLetter(templateID:title:from:)` may or may not set `linkedResumeID` or `pageSize`; the editor sets both explicitly.
- `ResumeFactory.blankResume` returns a `templateID` that `TemplateLibrary.spec(id:)` resolves. If not, `EditorRender.template(id:)` falls back to the default template.
- `ExportFlowSheet` reads `ExportGate` from the environment.
- `SampleContent.coverLetter()` returns a letter that can be rendered with any `CoverLetterTemplateSpec`.

## Known gaps

- No screenshots, so the design critique, accessibility review and UX copy review from the design rule are still to run once CI produces simulator images.
- No drag handles for entries, bullets and skill groups (menus only).
- Photo cropping is not offered; the photo is scaled down only, as specified.
- Style changes are not undoable beyond "Reset to template".
- Cover letter editor has no section manager (not needed) and no photo.
- Write-time collisions: none found when grepping `Sources/` for the type names above on the day of writing.

## Audit fixes (2026-11-16)

- Stale editor copy, large photo crash, preview render storm, thumbnail rendering: see the behaviour summary above.
- Dynamic Type: `CK.Font.title` / `CK.Font.headline` now scale with UIFontMetrics (relative to Title 1 and Headline) when the view is built, so every screen using them scales. In views, `.ckTitleFont(_:)` / `.ckHeadlineFont(_:)` (Theme.swift, `@ScaledMetric`) follow live size changes and parent `dynamicTypeSize` caps; the editors, card titles, sheets, `EdUnavailableView` and `SectionTitle` use them. The existing `ckTitle` / `ckHeadline` in ComponentsCommon no longer double scale. Bars cap growth: the navigation title block and bottom toolbar buttons at `.xxxLarge` (toolbar buttons show the large content viewer on long press), the Edit / Preview switch at `.accessibility2`. Card titles and subtitles wrap.
- Page footers on pages 2 and later: see `docs/handoff/engine.md`.
- Accessibility: `EdModeSwitch` is presented to VoiceOver as a segmented Picker (`accessibilityRepresentation`) with 44 pt segments; toolbar buttons have hints; card headers carry the header trait and plain hints; section rows have Move up / Move down actions, a position hint and an announcement after a move (`EdReorderActions`); hidden sections use an eye.slash icon and graphite text instead of 72 percent opacity, so contrast is kept. New `CK.Palette.placeholder` (light #6A6E6B, dark #8E928D, at least 4.5:1 on surface and ivory) replaces graphite at 60 percent for field prompts. Swatch borders use graphite at 55 percent so dark swatches stay visible in dark mode. Hints no longer say "double tap". Reduce Motion was already respected (card expand, mode switch, skeletons).
- `EdUnavailableView` takes optional `backTitle` / `onBack`.

Not done here: cover letter rows (`CoverLetterListView`, worker A), settings headers (Profile, worker B) and `ATSCheckView` (worker B) pick up scaling through `CK.Font.*`, but were not checked for clipping at AX3 and above. Nothing was checked on a simulator, and the design critique, accessibility review and UX copy review on real screenshots are still to run.

## Riskiest compile spots

1. `PDFPreview.swift`: `@MainActor` `Coordinator` conforming to `UIGestureRecognizerDelegate`, `NotificationCenter` observer tokens, `dismantleUIView` signature.
2. `LivePreviewRenderer.swift`: `withTaskCancellationHandler(operation:onCancel:)` inside a `Task` on the main actor, `@Sendable` render closure capturing value types.
3. `EditorComponents.swift`: `EdDisclosureCard` generic struct with `@ViewBuilder` closure properties and a constrained extension initializer (`Accessory == EmptyView`).
4. `AutosaveDraft.swift`: `didSet` observer on a `@Published` generic optional, and the `@MainActor` closure type for `persist`.
5. `ResumeEditorView.swift`: `ForEach(resume.sections) { $section in ... }` over a `Binding<[ResumeSection]>` obtained via `Binding($draft.doc)`; `@ToolbarContentBuilder` with a `.bottomBar` group.
6. `EntryEditors.swift`: `ForEach($section.entries) { $entry in let index = ...; ... }` with a local `let` inside the builder.
7. `TemplateThumbnail.swift`: `ThumbnailRenderer` actor with a static `NSCache` and a `@Sendable` produce closure.
8. `Button(_:systemImage:role:action:)` initialisers (iOS 17) used in menus.

## Tests

`EditorSupportTests.swift`: list reordering (index and IndexSet semantics), section helpers, month/year helpers, token and text helpers, file names, photo size maths, ImageIO photo processing (6000 x 4000 JPEG to 800 px, 3000 x 3000 transparent PNG flattened, EXIF orientation 6, no upscaling, byte and pixel limits, bad data), style limits.
`EditorPreviewQueueTests.swift`: `PreviewRenderQueue` coalescing (one in flight, one pending, latest wins, cancel) and `LivePreviewRenderer` end to end (20 immediate requests render twice, a debounced burst renders once, cancel renders nothing).
`EditorContentTests.swift`: writing examples are non-empty, unique, free of em-dashes and placeholders; entry labels; blank preview mapper; cover letter suggestions and prefill.

## New compile risks (audit fixes)

1. `AutosaveDraft.start(persist:)` now takes `(@MainActor (Doc) -> Bool)?`; the editors pass multi-statement closures.
2. `.onReceive(store.$resumes)` relies on the projected publisher of a `@Published private(set)` property being readable from the view.
3. `accessibilityRepresentation { Picker ... }` in `EdModeSwitch` and `accessibilityShowsLargeContentViewer { Label }` in `EdToolbarButton`.
4. ImageIO dictionaries (`[CFString: Any] as CFDictionary`) and `CGImageDestinationCreateWithData(output as CFMutableData, ...)` in `PhotoProcessor`; `Result<Data, PhotoProcessor.Failure>` returned from `Task.detached`.
5. `CKResumeThumbnail` uses a private `Request: Equatable` holding a `Resume` as the `.task(id:)` value.
6. Timing tests in `EditorLivePreviewRendererTests` poll up to 6 s; a very slow CI runner could need a longer loop.
