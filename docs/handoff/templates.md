# Templates handoff

Owner: templates. Written on a Windows PC with no Mac. **I could not compile or run anything.** No Swift was built and no test was executed. I checked bracket balance and argument order with small scripts, and I verified palette contrast, numeric ranges, category counts, design-tuple uniqueness and the ATS count with a Python script that also generated `TemplateLibrary.swift`. macOS CI is the first real compile.

## Files

| File | Purpose |
|---|---|
| `Sources/Templates/TemplateLibrary.swift` | 30 `TemplateSpec` values, `defaultTemplateID`, `spec(id:)` |
| `Sources/Templates/CoverLetterTemplateLibrary.swift` | 10 `CoverLetterTemplateSpec` values, `spec(id:)` |
| `Sources/Templates/SampleContent.swift` | 15 fictional personas, `resume(for:)`, `coverLetter()`, `sampleLabel` |
| `Sources/Templates/ResumeFactory.swift` | `newResume`, `blankResume`, `newCoverLetter` |
| `Tests/TemplateLibraryTests.swift` | counts, ids, variety, ATS rules, ranges, contrast (also holds the shared `TemplateTestColor` helper) |
| `Tests/TemplateCoverLetterTests.swift` | cover letter library checks |
| `Tests/TemplateSampleContentTests.swift` | sample content checks |
| `Tests/TemplateResumeFactoryTests.swift` | factory checks |

## Public API (matches the contract)

```swift
enum TemplateLibrary {
    static let all: [TemplateSpec]                 // exactly 30
    static let defaultTemplateID: String           // "ck.professional.executive" (ATS friendly)
    static func spec(id: String) -> TemplateSpec?
    static func templates(in category: TemplateCategory) -> [TemplateSpec]   // extra helper
}
enum CoverLetterTemplateLibrary {
    static let all: [CoverLetterTemplateSpec]      // exactly 10
    static func spec(id: String) -> CoverLetterTemplateSpec?
    static func spec(matchingResumeTemplateID: String) -> CoverLetterTemplateSpec?   // extra helper
}
enum SampleContent {
    static func resume(for template: TemplateSpec) -> Resume
    static func coverLetter() -> CoverLetter
    static let sampleLabel = "Sample content, fictional person"
}
enum ResumeFactory {
    static func newResume(template: TemplateSpec, title: String, pageSize: PageSize) -> Resume
    static func blankResume(title: String, pageSize: PageSize) -> Resume
    static func newCoverLetter(templateID: String, title: String, from resume: Resume?) -> CoverLetter
    static let requiredKinds: [SectionKind]                                   // extra helper
    static func sectionKinds(for template: TemplateSpec) -> [SectionKind]     // extra helper
}
```

Deviations from the contract: none in signatures. The extra helpers are optional to use.

## Design direction

I used the frontend-design and canvas-design guidance for the type and colour decisions. Distinctness comes from the combination of layout, header, heading style, entry layout, bullets, skill style, fonts, sizes, spacing and palette, not from recolouring one design.

- Palette: navy, forest, oxblood, slate, bronze and ink, all dark (accent luminance under 0.3). No neon. Bronze appears only on Business Elite, Elegant and Visual Portfolio.
- Type: serif headings (Baskerville, Didot, Cochin, Palatino, New York) over a text face for the formal templates; Futura, Optima, Gill Sans and Menlo headings for the creative and technical ones. System fonts only.
- Each of the 30 differs on the (layout, header, heading style, entry layout, heading font, body font) tuple, and a second test also compares bullets, skill style, accent and base size.
- Ids are `ck.<category>.<slug>`. The category part for Entry Level is `entry` (for example `ck.entry.fresh-graduate`).

## What the renderer owner needs to know

- **ATS friendly** means: `singleColumn`, `photo == .none`, no sidebar sections, header not `banner` or `sidebarCard`, heading style not `boxedLabel` or `sideLabel`, entry layout not `dateGutter`, skill style not `bulletColumns`, and default section titles. 14 templates qualify. A test asserts the flag equals this rule for every template.
- `sidebarCard` is used only with `sidebarLeft` and `sidebarRight`. `banner` goes with a non-nil `headerFillHex`, and banner text is assumed to be white (fill contrast with white is at least 4.5:1).
- `headerThenTwoColumn` uses `sidebarFraction` and `sidebarSections` for the right rail. Three of the four rails have a light `sidebarFillHex` with dark `sidebarTextHex`. Researcher has no fill (nil, nil), so draw its rail unfilled, with a hairline if you like.
- Sidebar fills: dark on Business Elite (navy), Creative Designer (charcoal) and Data Analyst (slate) with light text; light tints on the others. On light fills, accent and muted text are at least 4.5:1 against the fill.
- `sidebarFraction` is 0.28 to 0.36 for every template, including single column ones where it is ignored.
- Photo: `sidebarTop` on 5 sidebar templates, `headerRight` on Professional Grid, Marketing Professional and Creative Minimal, `none` elsewhere.
- `bullets: .none` is used once (Editorial). `uppercaseHeadings == false` goes with small caps, plain bold and mixed-case headings.
- Margins 34 to 56 pt (inside the 28 to 56 range), base size 9.5 to 11 pt, name size 26 to 38 pt, heading size 10 to 11.5 pt, line spacing 1.14 to 1.25, heading tracking 0.2 to 2.0 pt.
- Sample resumes use default section titles and A4. Section order is main sections, then sidebar sections.

## The 30 templates

| # | Template (id) | Category | Layout | Header | Heading | Entry | Fonts (heading / body) | Accent | ATS | Pages |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Executive (`ck.professional.executive`) | Professional | singleColumn | ruledMonogram | uppercaseRule | dateRight | baskerville / charter | #1B3358 | yes | 2 |
| 2 | Corporate (`ck.professional.corporate`) | Professional | singleColumn | leftAligned | smallCapsAccent | dateBelow | helveticaNeue / helveticaNeue | #3E5566 | yes | 2 |
| 3 | Modern Professional (`ck.professional.modern-professional`) | Professional | headerThenTwoColumn | splitContact | accentBar | dateRight | avenirNext / sfPro | #1F4D3A | no | 1 |
| 4 | Classic Professional (`ck.professional.classic-professional`) | Professional | singleColumn | centered | dottedRule | dateRight | palatino / palatino | #6E1F2B | yes | 1 |
| 5 | Business Elite (`ck.professional.business-elite`) | Professional | sidebarLeft | sidebarCard | uppercaseRule | dateBelow | didot / avenirNext | #85682A | no | 2 |
| 6 | Senior Management (`ck.professional.senior-management`) | Professional | singleColumn | splitContact | plainBold | stacked | newYork / sfPro | #253241 | yes | 2 |
| 7 | Modern Minimal (`ck.modern.modern-minimal`) | Modern | singleColumn | leftAligned | plainBold | dateRight | sfPro / sfPro | #2B3138 | yes | 1 |
| 8 | Contemporary (`ck.modern.contemporary`) | Modern | sidebarRight | sidebarCard | smallCapsAccent | dateRight | avenirNext / avenirNext | #23406B | no | 1 |
| 9 | Elegant (`ck.modern.elegant`) | Modern | singleColumn | centered | uppercaseRule | dateBelow | cochin / hoeflerText | #85682A | yes | 1 |
| 10 | Clean Lines (`ck.modern.clean-lines`) | Modern | singleColumn | leftAligned | uppercaseRule | dateRight | futura / helveticaNeue | #2F4B5E | yes | 1 |
| 11 | Modern Classic (`ck.modern.modern-classic`) | Modern | headerThenTwoColumn | ruledMonogram | smallCapsAccent | dateBelow | georgia / gillSans | #17402F | no | 2 |
| 12 | Professional Grid (`ck.modern.professional-grid`) | Modern | headerThenTwoColumn | banner | boxedLabel | dateRight | sfPro / charter | #1F3F6E | no | 2 |
| 13 | Creative Designer (`ck.creative.creative-designer`) | Creative | sidebarLeft | sidebarCard | accentBar | stacked | futura / avenirNext | #6E1F2B | no | 1 |
| 14 | Marketing Professional (`ck.creative.marketing-professional`) | Creative | singleColumn | banner | boxedLabel | dateRight | gillSans / helveticaNeue | #1F4D3A | no | 1 |
| 15 | Visual Portfolio (`ck.creative.visual-portfolio`) | Creative | sidebarRight | sidebarCard | dottedRule | dateBelow | optima / optima | #7A5C1E | no | 1 |
| 16 | Creative Minimal (`ck.creative.creative-minimal`) | Creative | singleColumn | leftAligned | sideLabel | stacked | avenirNext / iowanOldStyle | #7A2633 | no | 1 |
| 17 | Editorial (`ck.creative.editorial`) | Creative | singleColumn | ruledMonogram | sideLabel | dateGutter | didot / georgia | #6B1E2A | no | 2 |
| 18 | Academic CV (`ck.academic.academic-cv`) | Academic | singleColumn | centered | uppercaseRule | dateRight | iowanOldStyle / iowanOldStyle | #22385C | yes | 2 |
| 19 | Researcher (`ck.academic.researcher`) | Academic | headerThenTwoColumn | leftAligned | dottedRule | dateBelow | baskerville / georgia | #2A5A4B | no | 2 |
| 20 | University Graduate (`ck.academic.university-graduate`) | Academic | singleColumn | leftAligned | accentBar | dateBelow | charter / avenirNext | #34546E | yes | 1 |
| 21 | Scientific CV (`ck.academic.scientific-cv`) | Academic | singleColumn | splitContact | sideLabel | dateRight | helveticaNeue / georgia | #2F4858 | no | 2 |
| 22 | Fresh Graduate (`ck.entry.fresh-graduate`) | Entry Level | singleColumn | centered | smallCapsAccent | dateRight | avenirNext / charter | #2A5A45 | yes | 1 |
| 23 | Student Resume (`ck.entry.student-resume`) | Entry Level | sidebarLeft | sidebarCard | boxedLabel | dateBelow | optima / sfPro | #1F4D3A | no | 1 |
| 24 | Internship Resume (`ck.entry.internship-resume`) | Entry Level | singleColumn | leftAligned | plainBold | dateBelow | georgia / helveticaNeue | #24406B | yes | 1 |
| 25 | First Job (`ck.entry.first-job`) | Entry Level | sidebarRight | sidebarCard | accentBar | stacked | gillSans / gillSans | #3E5566 | no | 1 |
| 26 | Software Engineer (`ck.technical.software-engineer`) | Technical | singleColumn | leftAligned | plainBold | dateRight | menlo / sfPro | #2C4A63 | yes | 2 |
| 27 | IT Professional (`ck.technical.it-professional`) | Technical | singleColumn | splitContact | accentBar | dateBelow | helveticaNeue / sfPro | #253241 | yes | 2 |
| 28 | Data Analyst (`ck.technical.data-analyst`) | Technical | sidebarLeft | sidebarCard | uppercaseRule | dateRight | futura / sfPro | #2F5D7A | no | 1 |
| 29 | Product Manager (`ck.technical.product-manager`) | Technical | singleColumn | leftAligned | smallCapsAccent | dateRight | newYork / avenirNext | #2B5B47 | yes | 2 |
| 30 | Project Manager (`ck.technical.project-manager`) | Technical | singleColumn | ruledMonogram | dottedRule | dateGutter | palatino / helveticaNeue | #3A4F63 | no | 2 |

Layout counts: 19 single column, 7 sidebar (4 left, 3 right), 4 header then two column. Header styles: leftAligned 9, sidebarCard 7, ruledMonogram 4, splitContact 4, centered 4, banner 2. Heading styles: uppercaseRule 6, smallCapsAccent 5, accentBar 5, dottedRule 4, plainBold 4, boxedLabel 3, sideLabel 3. Entry layouts: dateRight 14, dateBelow 10, stacked 4, dateGutter 2.

## Cover letter templates (10)

| Id | Header | Fonts (heading / body) | Accent | Pairs with |
|---|---|---|---|---|
| ck.letter.executive | letterhead | baskerville / charter | #1B3358 | ck.professional.executive |
| ck.letter.corporate | leftBlock | helveticaNeue / helveticaNeue | #3E5566 | ck.professional.corporate |
| ck.letter.classic | centered | palatino / palatino | #6E1F2B | ck.professional.classic-professional |
| ck.letter.minimal | rightBlock | sfPro / sfPro | #2B3138 | ck.modern.modern-minimal |
| ck.letter.elegant | sideRule | cochin / hoeflerText | #85682A | ck.modern.elegant |
| ck.letter.grid | banner (#1B2F4E) | sfPro / charter | #1F3F6E | ck.modern.professional-grid |
| ck.letter.editorial | letterhead | didot / georgia | #6B1E2A | ck.creative.editorial |
| ck.letter.academic | leftBlock | iowanOldStyle / iowanOldStyle | #22385C | ck.academic.academic-cv |
| ck.letter.marketing | banner (#17382A) | gillSans / helveticaNeue | #1F4D3A | ck.creative.marketing-professional |
| ck.letter.engineer | sideRule | menlo / sfPro | #2C4A63 | ck.technical.software-engineer |

All six header layouts are used. Each pair shares heading font, body font, accent, text colour and banner fill (a test checks this).

## Sample content

15 invented personas, each tied to a category, industry and level: operations executive (Daniela Whitcombe), finance manager (Marcus Lindqvist), project manager (Tomas Ibarra), product manager (Aisha Rahman), marketing lead (Tessa Okafor), nurse (Grace Mwangi), secondary teacher (Claire Hartley), software engineer (Samuel Okonkwo), UX designer (Noor Haddad), IT administrator (Ravi Kulkarni), data analyst (Sofia Marchetti), postdoctoral researcher (Hannah Lindgren), new graduate (Jordan Reyes), student (Amara Singh), first-job seeker (Diego Park). Companies, schools, journals, awards and numbers are invented; emails use `example.com`; phone numbers use 555 style ranges. The mapping from template id to persona is the `persona(for:)` switch, with a fallback by category.

Length control: each persona is written at full length (roughly two pages for the senior ones). For one-page templates `fit(_:budget:)` trims the least important lines (older bullets, extra entries, older jobs) until the sample is under a word budget of about 470, and never removes a whole section. The cover letter sample is by Marcus Lindqvist for a finance role (template `ck.letter.corporate`).

## Known gaps and risks

1. **Not compiled, not run.** Expect small compile fixes on the first CI run. The riskiest spots are the large literal arrays in `SampleContent.swift` (type-checker time) and the tuple-returning helper `entryWithMostBullets`.
2. **Page fit is an estimate.** I could not render. One-page samples are trimmed to about 470 words, and two-page samples run about 500 to 700 words. Real fit depends on the renderer, margins and sidebar widths. Adjust `onePageWordBudget` or the persona text if previews look short or overflow. The tests only assert loose word ranges (one page 220 to 560, two pages at least 400).
3. **No visual review.** The brief asked for screenshots plus design critique, accessibility review and UX copy review before delivery. Templates are pure data and the renderer belongs to another owner, so there was nothing to screenshot. Run a thumbnail pass once the renderer exists. Text contrast was checked numerically.
4. **Fonts.** I did not verify on a device that every chosen family has a bold face on iOS 17. Didot and Cochin are used for headings and short letters only.
5. **`SampleContent.swift` is about 1,100 lines**, over the 400 line guide. Ownership allowed only four source files, so the personas stay together there. Splitting into `SampleContent+Personas.swift` is a safe follow-up if the lead allows new files.
6. **Gutter and side-label templates** (Editorial, Project Manager, Creative Minimal, Scientific CV) assume the renderer can fit a left gutter inside the main column on A4 and US Letter.
7. **Sidebar sections.** The Student sample puts skills, languages and interests in the sidebar through `sidebarSections`. If the renderer ignores that list, they will appear in the main column.
8. Academic CV and Scientific CV use the same Hannah Lindgren content with a different section order (education first versus experience first).
