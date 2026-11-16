import SwiftUI

/// Template values shown while an override is not set.
struct StyleDefaults {
    let accentHex: String
    let bodyFont: FontChoice
    let headingFont: FontChoice
    let marginPoints: Double

    init(template: TemplateSpec) {
        accentHex = template.accentHex
        bodyFont = template.bodyFont
        headingFont = template.headingFont
        marginPoints = template.marginSide
    }

    init(letterTemplate: CoverLetterTemplateSpec) {
        accentHex = letterTemplate.accentHex
        bodyFont = letterTemplate.bodyFont
        headingFont = letterTemplate.headingFont
        marginPoints = letterTemplate.marginSide
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
struct EdStyleControls: View {
    @Binding var style: StyleOverrides
    @Binding var pageSize: PageSize
    let defaults: StyleDefaults
    var limits: StyleLimits = .standard
    var showsPhotoToggle = true

    private static let swatches: [(name: String, hex: String)] = [
        ("Forest", "#1F4D3A"), ("Navy", "#1F3A5F"), ("Indigo", "#3B3F8F"), ("Plum", "#6B2D5C"),
        ("Brick", "#9A2F2F"), ("Copper", "#A5521D"), ("Bronze", "#7A5C1E"), ("Teal", "#2F6F73"),
        ("Slate", "#444B52"), ("Black", "#111111")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            accentSection
            fontSection(title: "Body font", selection: $style.bodyFont, fallback: defaults.bodyFont)
            fontSection(title: "Heading font", selection: $style.headingFont, fallback: defaults.headingFont)
            slidersSection
            pageSection
            if showsPhotoToggle {
                Toggle(isOn: $style.showPhoto) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Show photo").font(CK.Font.body).foregroundStyle(CK.Palette.ink)
                        Text("Only templates with a photo area use it.").font(CK.Font.caption).foregroundStyle(CK.Palette.graphite)
                    }
                }
                .tint(CK.Palette.forest)
                .frame(minHeight: 44)
            }
            EdTextButton(title: "Reset to template", systemImage: "arrow.counterclockwise") {
                style = StyleOverrides()
            }
        }
    }

    // MARK: Accent

    private var currentAccent: String { (style.accentHex ?? defaults.accentHex).uppercased() }

    private var accentSection: some View {
        VStack(alignment: .leading, spacing: CK.Space.s + 2) {
            sectionLabel("Accent color")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button { style.accentHex = nil } label: {
                        Text("Template")
                            .font(CK.Font.label)
                            .foregroundStyle(style.accentHex == nil ? CK.Palette.onForest : CK.Palette.ink)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(style.accentHex == nil ? CK.Palette.forest : CK.Palette.stone))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(style.accentHex == nil ? .isSelected : [])
                    ForEach(Self.swatches, id: \.hex) { swatch in
                        swatchButton(name: swatch.name, hex: swatch.hex)
                    }
                }
                .padding(.vertical, 2)
            }
            ColorPicker(selection: customColorBinding, supportsOpacity: false) {
                Text("Custom color").font(CK.Font.body).foregroundStyle(CK.Palette.ink)
            }
            .frame(minHeight: 44)
        }
    }

    private func swatchButton(name: String, hex: String) -> some View {
        let selected = style.accentHex?.uppercased() == hex
        return Button { style.accentHex = hex } label: {
            Circle()
                .fill(Color(hexString: hex))
                .frame(width: 32, height: 32)
                .overlay(Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5))
                .overlay {
                    if selected {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                    }
                }
                .padding(6)
                .overlay(Circle().strokeBorder(selected ? CK.Palette.ink : Color.clear, lineWidth: 1.5))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var customColorBinding: Binding<Color> {
        Binding(
            get: { Color(hexString: currentAccent) },
            set: { style.accentHex = UIColor($0).hexString }
        )
    }

    // MARK: Fonts

    private func fontSection(title: String, selection: Binding<FontChoice?>, fallback: FontChoice) -> some View {
        VStack(alignment: .leading, spacing: CK.Space.s + 2) {
            sectionLabel(title)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CK.Space.s) {
                    fontChip(text: "Template (\(fallback.displayName))", font: fallback.edPreviewFont(size: 16),
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
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Sliders

    private var slidersSection: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            slider(title: "Text size", valueText: "\(Int((style.fontScale * 100).rounded())) percent",
                   value: Binding(get: { style.fontScale }, set: { style.fontScale = $0 }),
                   range: limits.fontScale, step: 0.01)
            slider(title: "Line spacing", valueText: String(format: "%.2f", style.lineSpacing),
                   value: Binding(get: { style.lineSpacing }, set: { style.lineSpacing = $0 }),
                   range: limits.lineSpacing, step: 0.01)
            slider(title: "Page margin", valueText: "\(Int(marginValue.rounded())) pt",
                   value: Binding(get: { marginValue }, set: { style.marginPoints = $0 }),
                   range: limits.margin, step: 1)
        }
    }

    private var marginValue: Double {
        min(max(style.marginPoints ?? defaults.marginPoints, limits.margin.lowerBound), limits.margin.upperBound)
    }

    private func slider(title: String, valueText: String, value: Binding<Double>,
                        range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                sectionLabel(title)
                Spacer()
                Text(valueText).font(CK.Font.caption.monospacedDigit()).foregroundStyle(CK.Palette.graphite)
            }
            Slider(value: value, in: range, step: step)
                .tint(CK.Palette.forest)
                .frame(minHeight: 44)
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
        }
    }

    // MARK: Page

    private var pageSection: some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            sectionLabel("Page size")
            Picker("Page size", selection: $pageSize) {
                ForEach(PageSize.allCases) { size in
                    Text(size.displayName).tag(size)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(CK.Font.label)
            .foregroundStyle(CK.Palette.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Sheet

struct StylePanelSheet: View {
    @Binding var style: StyleOverrides
    @Binding var pageSize: PageSize
    let defaults: StyleDefaults
    var showsPhotoToggle = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                EdStyleControls(style: $style, pageSize: $pageSize, defaults: defaults, showsPhotoToggle: showsPhotoToggle)
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
