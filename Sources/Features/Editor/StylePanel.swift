import SwiftUI

/// Template values shown while an override is not set.
struct StyleDefaults {
    let accentHex: String
    let bodyFont: FontChoice
    let headingFont: FontChoice
    let marginPoints: Double
    let textHex: String
    /// The resume template. nil for cover letters, which hides the resume-only groups.
    let template: TemplateSpec?
    /// Header band colour of the template, when it has one.
    let headerFillHex: String?
    /// True when the document's header can show a filled band.
    let letterHasBanner: Bool

    var isLetter: Bool { template == nil }

    init(template: TemplateSpec) {
        accentHex = template.accentHex
        bodyFont = template.bodyFont
        headingFont = template.headingFont
        marginPoints = template.marginSide
        textHex = template.textHex
        self.template = template
        headerFillHex = template.headerFillHex
        letterHasBanner = false
    }

    init(letterTemplate: CoverLetterTemplateSpec) {
        accentHex = letterTemplate.accentHex
        bodyFont = letterTemplate.bodyFont
        headingFont = letterTemplate.headingFont
        marginPoints = letterTemplate.marginSide
        textHex = letterTemplate.textHex
        template = nil
        headerFillHex = letterTemplate.headerFillHex
        letterHasBanner = letterTemplate.header == .banner
    }
}

extension FontChoice {
    /// Each font name is shown in its own typeface.
    func edPreviewFont(size: CGFloat) -> Font {
        switch self {
        case .sfPro: return Font.system(size: size)
        case .newYork: return Font.system(size: size, design: .serif)
        default: return Font.custom(familyName ?? "", size: size)
        }
    }
}

// MARK: - Controls

/// All style controls without any navigation chrome, so the blank builder can embed them.
/// Everything here edits `StyleOverrides`; `DocumentRenderer` applies it, so preview and PDF match.
struct EdStyleControls: View {
    @Binding var style: StyleOverrides
    @Binding var pageSize: PageSize
    let defaults: StyleDefaults
    var limits: StyleLimits = .standard
    var showsPhotoToggle = true
    /// Set false to hide header, headings, entries, bullets, skills and dates. Letters never show them.
    var showsResumeStructure = true

    @State private var expanded: Set<String> = ["color", "type"]

    static let accentSwatches: [EdSwatch] = [
        EdSwatch(name: String(localized: "Forest"), hex: "#1F4D3A"), EdSwatch(name: String(localized: "Navy"), hex: "#1F3A5F"),
        EdSwatch(name: String(localized: "Indigo"), hex: "#3B3F8F"), EdSwatch(name: String(localized: "Plum"), hex: "#6B2D5C"),
        EdSwatch(name: String(localized: "Brick"), hex: "#9A2F2F"), EdSwatch(name: String(localized: "Copper"), hex: "#A5521D"),
        EdSwatch(name: String(localized: "Bronze"), hex: "#7A5C1E"), EdSwatch(name: String(localized: "Teal"), hex: "#2F6F73"),
        EdSwatch(name: String(localized: "Slate"), hex: "#444B52"), EdSwatch(name: String(localized: "Black"), hex: "#111111")
    ]
    static let textSwatches: [EdSwatch] = [
        EdSwatch(name: String(localized: "Charcoal"), hex: "#1F2421"), EdSwatch(name: String(localized: "Black"), hex: "#111111"),
        EdSwatch(name: String(localized: "Ink blue"), hex: "#1C2A3A"), EdSwatch(name: String(localized: "Graphite"), hex: "#3A3F44"),
        EdSwatch(name: String(localized: "Espresso"), hex: "#3B2F2A")
    ]
    static let sidebarSwatches: [EdSwatch] = [
        EdSwatch(name: String(localized: "Mist"), hex: "#EEF1F4"), EdSwatch(name: String(localized: "Sage"), hex: "#E9F0EC"),
        EdSwatch(name: String(localized: "Linen"), hex: "#F4F0E6"), EdSwatch(name: String(localized: "Forest"), hex: "#1F4D3A"),
        EdSwatch(name: String(localized: "Navy"), hex: "#1B2F4E"), EdSwatch(name: String(localized: "Charcoal"), hex: "#26343F")
    ]
    static let bandSwatches: [EdSwatch] = [
        EdSwatch(name: String(localized: "Forest"), hex: "#17382A"), EdSwatch(name: String(localized: "Navy"), hex: "#1B2F4E"),
        EdSwatch(name: String(localized: "Plum"), hex: "#4A2340"), EdSwatch(name: String(localized: "Charcoal"), hex: "#22272B"),
        EdSwatch(name: String(localized: "Bronze"), hex: "#6B5124")
    ]

    private var structureTemplate: TemplateSpec? {
        guard showsResumeStructure else { return nil }
        return defaults.template
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            overview
            colorGroup
            typeGroup
            if let template = structureTemplate {
                layoutGroup(template)
            }
            spacingGroup
            pageGroup
            EdLanguageStyleGroup(language: $style.language,
                                 isLetter: defaults.isLetter,
                                 isExpanded: isExpanded("language"))
            if showsPhotoToggle && !defaults.isLetter {
                photoGroup
            }
        }
    }

    private func isExpanded(_ key: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(key) },
            set: { open in
                if open { expanded.insert(key) } else { expanded.remove(key) }
            }
        )
    }

    // MARK: Overview

    private var hasChanges: Bool { style != StyleOverrides() }

    private var overview: some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            Text(defaults.isLetter
                 ? String(localized: "Changes show in the preview and in the exported file.")
                 : String(localized: "Changes show in the preview and in the exported file. A champagne dot marks the template's own choice."))
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.graphite)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                style = StyleOverrides()
            } label: {
                Label("Reset everything to template", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.ckSecondary)
            .disabled(!hasChanges)
            .opacity(hasChanges ? 1 : 0.55)
            .accessibilityHint("Removes every style change on this document")
        }
    }

    // MARK: Color

    private var colorModified: Bool {
        style.accentHex != nil || style.textHex != nil || style.sidebarFillHex != nil || style.headerFillHex != nil
    }

    private var showsBandColor: Bool {
        if defaults.isLetter { return defaults.letterHasBanner }
        guard let template = defaults.template else { return false }
        return effectiveHeader(template) == .banner
    }

    private var colorGroup: some View {
        EdStyleGroup(title: String(localized: "Color"),
                     summary: colorModified ? String(localized: "Custom colors") : String(localized: "Template colors"),
                     systemImage: "paintpalette",
                     isModified: colorModified,
                     onReset: {
                         style.accentHex = nil
                         style.textHex = nil
                         style.sidebarFillHex = nil
                         style.headerFillHex = nil
                     },
                     isExpanded: isExpanded("color")) {
            EdColorRow(title: String(localized: "Accent"), help: String(localized: "Headings, lines and highlights."),
                       swatches: Self.accentSwatches, selection: $style.accentHex, templateHex: defaults.accentHex)
            EdColorRow(title: String(localized: "Text"), help: String(localized: "Body text. Dark colors print and read best."),
                       swatches: Self.textSwatches, selection: $style.textHex, templateHex: defaults.textHex)
            if let template = structureTemplate, template.hasSidebarColumn {
                EdColorRow(title: String(localized: "Sidebar background"), help: String(localized: "Text in the sidebar switches to stay readable."),
                           swatches: Self.sidebarSwatches, selection: $style.sidebarFillHex,
                           templateHex: template.sidebarFillHex ?? defaults.accentHex)
            }
            if showsBandColor {
                EdColorRow(title: String(localized: "Header band"), help: String(localized: "Name and contact text switch to stay readable."),
                           swatches: Self.bandSwatches, selection: $style.headerFillHex,
                           templateHex: defaults.headerFillHex ?? (style.accentHex ?? defaults.accentHex))
            }
        }
    }

    // MARK: Typography

    private var typeModified: Bool {
        style.bodyFont != nil || style.headingFont != nil || style.fontScale != 1 || style.lineSpacing != 1
            || style.nameScale != 1 || style.uppercaseHeadings != nil
    }

    private var typeGroup: some View {
        let bodyChoice: FontChoice = style.bodyFont ?? defaults.bodyFont
        let headingChoice: FontChoice = style.headingFont ?? defaults.headingFont
        let sizeText: String = percent(style.fontScale)
        return EdStyleGroup(title: String(localized: "Text and fonts"),
                            summary: String(localized: "\(headingChoice.displayName) and \(bodyChoice.displayName), \(sizeText) size"),
                            systemImage: "textformat",
                            isModified: typeModified,
                            onReset: {
                                style.bodyFont = nil
                                style.headingFont = nil
                                style.fontScale = 1
                                style.lineSpacing = 1
                                style.nameScale = 1
                                style.uppercaseHeadings = nil
                            },
                            isExpanded: isExpanded("type")) {
            fontRow(title: String(localized: "Heading font"), selection: $style.headingFont, fallback: defaults.headingFont)
            fontRow(title: String(localized: "Body font"), selection: $style.bodyFont, fallback: defaults.bodyFont)
            EdStyleSlider(title: String(localized: "Text size"), valueText: percent(style.fontScale),
                          value: clampedBinding(\.fontScale, limits.fontScale),
                          range: limits.fontScale, step: 0.01)
            EdStyleSlider(title: String(localized: "Name size"), help: String(localized: "Your name at the top of the page."),
                          valueText: percent(style.nameScale),
                          value: clampedBinding(\.nameScale, StyleOverrides.nameScaleRange),
                          range: StyleOverrides.nameScaleRange, step: 0.05)
            EdStyleSlider(title: String(localized: "Line spacing"), valueText: percent(style.lineSpacing),
                          value: clampedBinding(\.lineSpacing, limits.lineSpacing),
                          range: limits.lineSpacing, step: 0.01)
            if let template = structureTemplate {
                capitalsRow(template)
            }
        }
    }

    private func fontRow(title: String, selection: Binding<FontChoice?>, fallback: FontChoice) -> some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            EdStyleLabel(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CK.Space.s) {
                    fontChip(text: String(localized: "Template (\(fallback.displayName))"), font: fallback.edPreviewFont(size: 16),
                             selected: selection.wrappedValue == nil) { selection.wrappedValue = nil }
                    ForEach(FontChoice.allCases) { choice in
                        fontChip(text: choice.displayName, font: choice.edPreviewFont(size: 17),
                                 selected: selection.wrappedValue == choice) { selection.wrappedValue = choice }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func fontChip(text: String, font: Font, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(font)
                .foregroundStyle(selected ? CK.Palette.onForest : CK.Palette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Capsule().fill(selected ? CK.Palette.forest : CK.Palette.stone))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
    }

    private func capitalsRow(_ template: TemplateSpec) -> some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            EdStyleLabel(title: String(localized: "Section titles"), help: String(localized: "Write section titles in capitals or as you typed them."))
            EdFlowLayout(spacing: CK.Space.s) {
                EdChoiceChip(title: String(localized: "Template"), selected: style.uppercaseHeadings == nil) { style.uppercaseHeadings = nil }
                EdChoiceChip(title: String(localized: "CAPITALS"), accessibilityText: String(localized: "Capitals"),
                             selected: style.uppercaseHeadings == true) { style.uppercaseHeadings = true }
                EdChoiceChip(title: String(localized: "As typed"), selected: style.uppercaseHeadings == false) { style.uppercaseHeadings = false }
            }
        }
    }

    // MARK: Layout and structure

    private var layoutModified: Bool {
        style.headerStyle != nil || style.headingStyle != nil || style.entryLayout != nil || style.bullets != nil
            || style.skillStyle != nil || style.sidebarPosition != nil || style.dateFormat != nil
    }

    private func effectiveHeader(_ template: TemplateSpec) -> HeaderStyle {
        if let wanted = style.headerStyle, template.supportsHeader(wanted) { return wanted }
        return template.header
    }

    private func effectiveHeading(_ template: TemplateSpec) -> SectionHeadingStyle {
        if let wanted = style.headingStyle, template.supportsHeading(wanted) { return wanted }
        return template.headingStyle
    }

    private var sampleAccent: Color { Color(hexString: style.accentHex ?? defaults.accentHex) }

    private func layoutGroup(_ template: TemplateSpec) -> some View {
        EdStyleGroup(title: String(localized: "Layout and structure"),
                     summary: layoutModified ? String(localized: "Custom layout") : String(localized: "Template layout"),
                     systemImage: "square.grid.3x2",
                     isModified: layoutModified,
                     onReset: {
                         style.headerStyle = nil
                         style.headingStyle = nil
                         style.entryLayout = nil
                         style.bullets = nil
                         style.skillStyle = nil
                         style.sidebarPosition = nil
                         style.dateFormat = nil
                     },
                     isExpanded: isExpanded("layout")) {
            if template.hasSidebarColumn {
                sidebarRow(template)
            }
            headerRow(template)
            headingRow(template)
            entryRow(template)
            bulletRow(template)
            skillsRow(template)
            dateRow()
        }
    }

    private func sidebarRow(_ template: TemplateSpec) -> some View {
        let templateSide: SidebarPosition = template.layout == .sidebarLeft ? .left : .right
        let current: SidebarPosition = style.sidebarPosition ?? templateSide
        return VStack(alignment: .leading, spacing: CK.Space.s) {
            EdStyleLabel(title: String(localized: "Sidebar side"))
            EdFlowLayout(spacing: CK.Space.s) {
                ForEach(SidebarPosition.allCases) { side in
                    EdChoiceChip(title: side == .left ? String(localized: "Left") : String(localized: "Right"),
                                 accessibilityText: side == .left ? String(localized: "Sidebar on the left") : String(localized: "Sidebar on the right"),
                                 selected: current == side,
                                 isTemplateChoice: side == templateSide) {
                        style.sidebarPosition = side == templateSide ? nil : side
                    }
                }
            }
        }
    }

    private func headerRow(_ template: TemplateSpec) -> some View {
        var options: [HeaderStyle] = TemplateSpec.offeredHeaderStyles.filter { template.supportsHeader($0) }
        if template.header == .sidebarCard {
            options.insert(.sidebarCard, at: 0)
        }
        let current: HeaderStyle = effectiveHeader(template)
        return VStack(alignment: .leading, spacing: CK.Space.s) {
            EdStyleLabel(title: String(localized: "Header"), help: String(localized: "Where your name, title and contact details sit."))
            EdFlowLayout(spacing: CK.Space.s) {
                ForEach(options, id: \.self) { option in
                    EdSampleChip(label: EdStyleNames.header(option),
                                 selected: current == option,
                                 isTemplateChoice: option == template.header,
                                 action: { style.headerStyle = option == template.header ? nil : option }) {
                        EdSamples.header(option, accent: sampleAccent)
                    }
                }
            }
        }
    }

    private func headingRow(_ template: TemplateSpec) -> some View {
        let options: [SectionHeadingStyle] = TemplateSpec.offeredHeadingStyles.filter { template.supportsHeading($0) }
        let current: SectionHeadingStyle = effectiveHeading(template)
        return VStack(alignment: .leading, spacing: CK.Space.s) {
            EdStyleLabel(title: String(localized: "Section titles style"))
            EdFlowLayout(spacing: CK.Space.s) {
                ForEach(options, id: \.self) { option in
                    EdSampleChip(label: EdStyleNames.heading(option),
                                 selected: current == option,
                                 isTemplateChoice: option == template.headingStyle,
                                 action: { style.headingStyle = option == template.headingStyle ? nil : option }) {
                        EdSamples.heading(option, accent: sampleAccent)
                    }
                }
            }
        }
    }

    private func entryRow(_ template: TemplateSpec) -> some View {
        let current: EntryLayout = style.entryLayout ?? template.entryLayout
        return VStack(alignment: .leading, spacing: CK.Space.s) {
            EdStyleLabel(title: String(localized: "Jobs and education"), help: String(localized: "How each entry shows its title and dates."))
            EdFlowLayout(spacing: CK.Space.s) {
                ForEach(TemplateSpec.offeredEntryLayouts, id: \.self) { option in
                    EdSampleChip(label: EdStyleNames.entry(option),
                                 selected: current == option,
                                 isTemplateChoice: option == template.entryLayout,
                                 action: { style.entryLayout = option == template.entryLayout ? nil : option }) {
                        EdSamples.entry(option, accent: sampleAccent)
                    }
                }
            }
        }
    }

    private func bulletRow(_ template: TemplateSpec) -> some View {
        let current: BulletStyle = style.bullets ?? template.bullets
        return VStack(alignment: .leading, spacing: CK.Space.s) {
            EdStyleLabel(title: String(localized: "Bullet points"))
            EdFlowLayout(spacing: CK.Space.s) {
                ForEach(TemplateSpec.offeredBullets, id: \.self) { option in
                    EdChoiceChip(title: EdStyleNames.bullet(option),
                                 glyph: option.glyph,
                                 selected: current == option,
                                 isTemplateChoice: option == template.bullets,
                                 accent: sampleAccent) {
                        style.bullets = option == template.bullets ? nil : option
                    }
                }
            }
        }
    }

    private func skillsRow(_ template: TemplateSpec) -> some View {
        let current: SkillStyle = style.skillStyle ?? template.skillStyle
        return VStack(alignment: .leading, spacing: CK.Space.s) {
            EdStyleLabel(title: String(localized: "Skills"))
            EdFlowLayout(spacing: CK.Space.s) {
                ForEach(TemplateSpec.offeredSkillStyles, id: \.self) { option in
                    EdSampleChip(label: EdStyleNames.skills(option),
                                 selected: current == option,
                                 isTemplateChoice: option == template.skillStyle,
                                 action: { style.skillStyle = option == template.skillStyle ? nil : option }) {
                        EdSamples.skills(option, accent: sampleAccent)
                    }
                }
            }
        }
    }

    private func dateRow() -> some View {
        let current: ResumeDateFormat = style.dateFormat ?? .monthName
        return VStack(alignment: .leading, spacing: CK.Space.s) {
            EdStyleLabel(title: String(localized: "Dates"))
            EdFlowLayout(spacing: CK.Space.s) {
                ForEach(ResumeDateFormat.allCases) { option in
                    EdChoiceChip(title: option.example,
                                 accessibilityText: String(localized: "Dates like \(option.example)"),
                                 selected: current == option,
                                 isTemplateChoice: option == .monthName) {
                        style.dateFormat = option == .monthName ? nil : option
                    }
                }
            }
        }
    }

    // MARK: Spacing

    private var spacingModified: Bool {
        style.sectionSpacing != 1 || style.entrySpacing != 1 || style.marginPoints != nil
    }

    private var spacingGroup: some View {
        EdStyleGroup(title: String(localized: "Spacing"),
                     summary: spacingModified ? String(localized: "Custom spacing") : String(localized: "Template spacing"),
                     systemImage: "arrow.up.and.down.text.horizontal",
                     isModified: spacingModified,
                     onReset: {
                         style.sectionSpacing = 1
                         style.entrySpacing = 1
                         style.marginPoints = nil
                     },
                     isExpanded: isExpanded("spacing")) {
            EdStyleSlider(title: defaults.isLetter ? String(localized: "Space between paragraphs") : String(localized: "Space between sections"),
                          valueText: percent(style.sectionSpacing),
                          value: clampedBinding(\.sectionSpacing, StyleOverrides.spacingRange),
                          range: StyleOverrides.spacingRange, step: 0.05)
            if !defaults.isLetter {
                EdStyleSlider(title: String(localized: "Space between entries"), help: String(localized: "The gap between jobs, degrees and other items."),
                              valueText: percent(style.entrySpacing),
                              value: clampedBinding(\.entrySpacing, StyleOverrides.spacingRange),
                              range: StyleOverrides.spacingRange, step: 0.05)
            }
            EdStyleSlider(title: String(localized: "Page margin"), help: String(localized: "White space around the edge of the page."),
                          valueText: marginText,
                          value: Binding(get: { marginValue }, set: { style.marginPoints = $0 }),
                          range: limits.margin, step: 1)
        }
    }

    private var marginText: String {
        let number: Int = Int(marginValue.rounded())
        return String(localized: "\(number) pt")
    }

    private var marginValue: Double {
        min(max(style.marginPoints ?? defaults.marginPoints, limits.margin.lowerBound), limits.margin.upperBound)
    }

    // MARK: Page

    private var pageGroup: some View {
        EdStyleGroup(title: String(localized: "Page"),
                     summary: pageSize.displayName,
                     systemImage: "doc",
                     isModified: false,
                     onReset: {},
                     isExpanded: isExpanded("page")) {
            VStack(alignment: .leading, spacing: CK.Space.s) {
                EdStyleLabel(title: String(localized: "Page size"), help: String(localized: "A4 is used in most countries. US Letter is used in the US and Canada."))
                Picker("Page size", selection: $pageSize) {
                    ForEach(PageSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
            }
        }
    }

    // MARK: Photo

    private var photoGroup: some View {
        EdPhotoStyleGroup(style: $style, template: defaults.template, isExpanded: isExpanded("photo"))
    }

    // MARK: Helpers

    private func percent(_ value: Double) -> String {
        let percent: Int = Int((value * 100).rounded())
        return String(localized: "\(percent)%")
    }

    private func clampedBinding(_ keyPath: WritableKeyPath<StyleOverrides, Double>, _ range: ClosedRange<Double>) -> Binding<Double> {
        Binding(
            get: { min(max(style[keyPath: keyPath], range.lowerBound), range.upperBound) },
            set: { style[keyPath: keyPath] = $0 }
        )
    }
}

// MARK: - Sheet

struct StylePanelSheet: View {
    @Binding var style: StyleOverrides
    @Binding var pageSize: PageSize
    let defaults: StyleDefaults
    var showsPhotoToggle = true
    var showsResumeStructure = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                EdStyleControls(style: $style, pageSize: $pageSize, defaults: defaults,
                                showsPhotoToggle: showsPhotoToggle,
                                showsResumeStructure: showsResumeStructure)
                    .padding(CK.Space.m)
            }
            .background(CK.Palette.ivory.ignoresSafeArea())
            .navigationTitle("Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.font(CK.Font.label)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }
}
