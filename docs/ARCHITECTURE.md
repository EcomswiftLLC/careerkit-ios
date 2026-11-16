# CareerKit architecture contract

App name on the App Store: **Resume Builder: CareerKit**. Home-screen name: CareerKit.
Bundle id `com.ecomswift.careerkit`, iOS 17+, Swift 5.10, SwiftUI, XcodeGen (`project.yml`), CI on macOS runners.

## Owner decisions that override anything else in the original brief

1. **The app is 100% free. There is NO StoreKit, NO subscription, NO in-app purchase, NO paywall, NO "Premium".**
   Do not import StoreKit anywhere. Do not mention prices, "premium", "pro", "unlock forever".
2. **AdMob is the only monetisation.** Two placements only:
   - Adaptive banner on browse screens (Home, My Resumes, Templates, Cover Letters, Profile). Never on the editor, never on the preview/export screens, never next to a primary button.
   - Rewarded video: exporting a finished document (PDF, Word, Rich Text, plain text or web page, to Files, Share sheet or Print for PDF) needs one completed rewarded video. One reward = one export of that document. Everything else (create, edit, preview, drafts, cover letters, ATS check) is free with no ad.
3. No interstitials, no app-open ads. User must opt in to the rewarded ad. Reward only in the official earned-reward callback.
4. Development uses Google test ad unit IDs through `Config/*.xcconfig` -> Info.plist keys `GADApplicationIdentifier`, `CKBannerAdUnitID`, `CKRewardedAdUnitID`. Never hardcode ids in Swift.
5. No paid AI API. No network is needed for core use. No account. Documents stay on device.
6. All 30 resume templates and 10 cover letter templates are free (no premium tier, no "Premium" filter).
7. Wording rule: plain, human, specific. No hype, no emoji, no em-dashes, no "unlock your potential" style copy. Never claim guaranteed ATS approval or job success.

## Module map and file ownership (one owner per directory; never edit another owner's files)

| Owner | Directory / files |
|---|---|
| Lead (already written, read only) | `Sources/Models/*`, `Sources/Templates/TemplateSpec.swift`, `Sources/DesignSystem/Theme.swift`, `project.yml`, `Config/*`, `Sources/Resources/Info.plist` (Ads owner may add keys) |
| engine | `Sources/Render/*`, `Sources/Persistence/*`, `Sources/Features/ATS/ATSAnalyzer.swift`, `Tests/Engine*` |
| templates | `Sources/Templates/TemplateLibrary.swift`, `CoverLetterTemplateLibrary.swift`, `SampleContent.swift`, `ResumeFactory.swift`, `Tests/Template*` |
| ads | `Sources/Ads/*`, `Sources/Resources/PrivacyInfo.xcprivacy`, Info.plist ad keys, `Tests/Ads*` |
| appui | `Sources/App/*`, `Sources/Features/Onboarding`, `Home`, `MyResumes`, `Templates`, `Profile`, `Sources/DesignSystem/Components*.swift` |
| editor | `Sources/Features/Editor`, `Preview`, `CoverLetters`, `ATS` (views only), `Tests/Editor*` |
| assets | `Sources/Resources/Assets.xcassets`, `design/`, `docs/store/*`, `website/`, `README.md`, legal docs |

## Public APIs (exact signatures other modules rely on)

### engine: Render
```swift
struct RenderedDocument { let pdfData: Data; let pageCount: Int; let pageSize: PageSize }

enum DocumentRenderer {
    /// Pure and thread-safe. Call from a background task. Same output is used for preview and export.
    static func render(_ resume: Resume, template: TemplateSpec) -> RenderedDocument
}
enum CoverLetterRenderer {
    static func render(_ letter: CoverLetter, template: CoverLetterTemplateSpec) -> RenderedDocument
}
struct PDFValidationReport { let passed: Bool; let issues: [String]; let extractedText: String; let pageCount: Int }
enum PDFValidator {
    static func extractText(from pdfData: Data) -> String
    /// Checks that every non-empty field of the resume appears in the PDF text, no blank pages, page size matches.
    static func validate(_ doc: RenderedDocument, resume: Resume) -> PDFValidationReport
}
```
Rendering uses Core Text / NSAttributedString drawn into `UIGraphicsPDFRenderer` (selectable text, link annotations for email, phone, URLs). Preview = `PDFView` showing `pdfData`. Never silently drop content: overflow flows to the next page.

#### Style overrides (user customisation)
`StyleOverrides` (in `Resume.swift`, also used by `CoverLetter`) holds every user style choice. Every field is optional or defaulted and the custom `init(from:)` uses `decodeIfPresent` (unknown enum values become nil), so older documents decode unchanged and `schemaVersion` stays 1.
- Original: `accentHex`, `bodyFont`, `headingFont`, `fontScale`, `lineSpacing`, `marginPoints`, `showPhoto`.
- Structure (nil = template): `headingStyle`, `headerStyle` (UI offers leftAligned, centered, splitContact, ruledMonogram, banner, monogramBadge, accentRuleLeft, centeredAccent, doubleRule), `entryLayout`, `bullets`, `skillStyle`, `uppercaseHeadings`, `sidebarPosition` (left/right, sidebar layouts only).
- Spacing multipliers (default 1): `sectionSpacing` and `entrySpacing` (0.7...1.6), `nameScale` (0.8...1.3).
- Colours (nil = template, "#RRGGBB"): `textHex`, `sidebarFillHex`, `headerFillHex`.
- Details (nil = template): `photoShape` (circle/rounded/square), `dateFormat` (`ResumeDateFormat`: "Jan 2024", "01/2024", "2024").

Where they apply, in one place each:
- `TemplateSpec.applying(_:)` (`Sources/Templates/TemplateSpec+Overrides.swift`) returns the effective spec for structure, spacing, name size and text/sidebar/header colours. `DocumentRenderer.render` calls it once, so every builder, the preview and the PDF see the same spec. Call it only on a library template (the multipliers are not idempotent). Invalid combinations keep the template value: banner with a full height sidebar, sidebarCard without a sidebar, sideLabel outside single column, sidebar side or fill on non-sidebar layouts, bad hex. A custom sidebar fill clears `sidebarTextHex` so readable text is recomputed; a photo in a replaced sidebar card moves to `headerRight`.
- `RenderStyle.make` keeps handling accent, fonts, text size, line spacing and margins, and carries `headingCaseOverride`, `photoShape` and `dateFormat` to the builders. For letters it also applies `textHex`, `headerFillHex`, `nameScale` and `sectionSpacing` (paragraph spacing).
- UI: `EdStyleControls` (`Sources/Features/Editor/StylePanel*.swift`) groups Color, Text and fonts, Layout and structure, Spacing, Page, Photo. Letters (`StyleDefaults(letterTemplate:)`) hide the resume-only groups automatically; `showsResumeStructure: false` hides them explicitly.

### engine: Persistence
```swift
@MainActor final class DocumentStore: ObservableObject {
    enum SaveState: Equatable { case idle, saving, saved(Date), failed(String) }
    @Published private(set) var resumes: [Resume]
    @Published private(set) var coverLetters: [CoverLetter]
    @Published private(set) var saveState: SaveState
    init(directory: URL? = nil)                       // nil = Application Support/CareerKit
    func resume(id: UUID) -> Resume?
    func coverLetter(id: UUID) -> CoverLetter?
    func upsert(_ resume: Resume)                     // sets updatedAt, debounced atomic save (0.6 s)
    func upsert(_ letter: CoverLetter)
    func delete(resumeID: UUID)
    func delete(coverLetterID: UUID)
    func duplicate(resumeID: UUID) -> Resume?         // title "<title> copy", new id
    func duplicate(coverLetterID: UUID) -> CoverLetter?
    func setArchived(_ archived: Bool, resumeID: UUID)
    func flushNow()                                   // synchronous save, call on scene background
    func deleteAllData() throws
    func makeBackupFile() throws -> URL               // JSON of everything in a temp file for the share sheet
}
```
Storage: one JSON file per document in `Documents/Resumes/<uuid>.json` and `CoverLetters/<uuid>.json` inside Application Support, atomic writes, a `.bak` copy kept of the previous version, corrupted files are moved to `Quarantine/` and never crash the app. `schemaVersion` migration hook.

### engine: ATS
```swift
struct ATSFinding: Identifiable { enum Severity { case good, info, warning }; let id = UUID(); let severity: Severity; let title: String; let detail: String }
struct ATSReport { let findings: [ATSFinding]; var warningCount: Int { get }; let disclaimer: String }
enum ATSAnalyzer { static func analyze(resume: Resume, template: TemplateSpec, pdfData: Data) -> ATSReport }
```
Checks: standard headings, contact info valid, dates present on jobs, summary present, text extraction readable, sidebar/multi-column warning from template, photo warning, unusual symbols, length guidance. The disclaimer states these are general guidance and not a score from any employer system.

### templates
```swift
enum TemplateLibrary {
    static let all: [TemplateSpec]                     // exactly 30, ids "ck.professional.executive" style
    static let defaultTemplateID: String
    static func spec(id: String) -> TemplateSpec?
}
enum CoverLetterTemplateLibrary { static let all: [CoverLetterTemplateSpec]  /* exactly 10 */; static func spec(id: String) -> CoverLetterTemplateSpec? }
enum SampleContent {
    static func resume(for template: TemplateSpec) -> Resume      // fictional person, clearly sample, realistic length
    static func coverLetter() -> CoverLetter
    static let sampleLabel = "Sample content, fictional person"
}
enum ResumeFactory {
    static func newResume(template: TemplateSpec, title: String, pageSize: PageSize) -> Resume   // empty sections in template order
    static func blankResume(title: String, pageSize: PageSize) -> Resume                          // isBlank = true, only personal + empty summary
    static func newCoverLetter(templateID: String, title: String, from resume: Resume?) -> CoverLetter
}
```

### ads
```swift
@MainActor final class AdsManager: ObservableObject {
    static let shared: AdsManager
    @Published private(set) var canRequestAds: Bool
    func start() async                                  // UMP consent -> ATT request (after consent) -> MobileAds.shared.start
    func presentPrivacyOptions()                        // UMP privacy options form, for Settings
    var privacyOptionsRequired: Bool { get }
}
struct BannerAdView: View { init() }                    // adaptive banner, collapses to zero height when no fill or no consent
final class RewardedAdController: ObservableObject {    // load / present / reward-callback handling
    enum State: Equatable { case idle, loading, ready, presenting, unavailable(String) }
    @Published var state: State
    func load()
    func present() async -> Bool                        // true ONLY when the earned-reward callback fired
}
@MainActor final class ExportGate: ObservableObject {
    /// Persisted. A grant belongs to one document id and one export.
    func hasGrant(for documentID: UUID) -> Bool
    func grant(for documentID: UUID)                    // called only after a verified reward
    func consume(for documentID: UUID)                  // called after the export really completed
}
/// The whole export experience: explanation, ad button, loading, retry, then ShareLink / Files / Print.
struct ExportFlowSheet: View {
    init(documentID: UUID, fileName: String, renderedProvider: @escaping () -> RenderedDocument)
}
```
`fileName` has no extension; the flow adds `.pdf`.

### appui and editor
```swift
// editor owner provides:
struct ResumeEditorView: View      { init(resumeID: UUID) }       // full editor + live preview toggle + export button
struct ResumePreviewView: View     { init(resumeID: UUID) }       // read only PDF preview with zoom + page navigation
struct NewResumeFlow: View         { init(templateID: String?, onCreated: (UUID) -> Void) }  // nil template = blank resume path
struct CoverLetterListView: View   { init() }
struct CoverLetterEditorView: View { init(letterID: UUID) }
struct ATSCheckView: View          { init(resumeID: UUID) }
struct TemplateThumbnail: View     { init(template: TemplateSpec, size: CGFloat) }  // renders SampleContent through DocumentRenderer, cached
// appui owns: CareerKitApp, RootTabView, AppState, Home, MyResumes, TemplateBrowser, Profile/Settings, Onboarding
```
Environment objects injected at the app root: `DocumentStore`, `AppState`, `ExportGate`, `AdsManager.shared`.
`AppState` (appui): `hasCompletedOnboarding`, `defaultPageSize`, `appearance` (system/light/dark), UserDefaults backed.

## Rules for every owner

- Do not run git, xcodegen, or any build; there is no Mac here. CI compiles on macOS. Write compile-safe Swift by being conservative: no exotic APIs, explicit types where inference is ambiguous, availability-safe for iOS 17.
- Google Mobile Ads SDK v12 API: `MobileAds.shared.start`, `RewardedAd.load(with:request:)`, `BannerView`, `Request()`, `AdSize`, `currentOrientationAnchoredAdaptiveBanner(width:)`. UMP v3: `ConsentInformation.shared`, `ConsentForm.loadAndPresentIfRequired(from:)`.
- Accessibility: Dynamic Type, VoiceOver labels on icon buttons, 44 pt hit targets, Reduce Motion respected.
- English strings in code now, but wrap user-visible strings in `String(localized:)` or `LocalizedStringKey` friendly forms so localisation can be added.
- Keep files focused (< 400 lines when practical). Add unit tests for pure logic.
- When finished, write a short `docs/handoff/<owner>.md` listing files, public API actually implemented (note any deviation from this contract), and known gaps.
