import SwiftUI

// Building blocks for the style panel: the collapsible group, the sample tiles drawn as tiny
// pages, the colour row and the slider row. Kept apart from `EdStyleControls` so each file stays small.

// MARK: - Group

/// A collapsible group with a serif title, a plain summary line and a reset button when something changed.
struct EdStyleGroup<Content: View>: View {
    let title: String
    let summary: String
    let systemImage: String
    let isModified: Bool
    let onReset: () -> Void
    @Binding var isExpanded: Bool
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: CK.Space.s + 4) {
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(CK.Palette.forest)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(CK.Font.headline(18))
                                .foregroundStyle(CK.Palette.ink)
                                .multilineTextAlignment(.leading)
                            Text(summary)
                                .font(CK.Font.caption)
                                .foregroundStyle(isModified ? CK.Palette.forest : CK.Palette.graphite)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: CK.Space.s)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CK.Palette.graphite)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .padding(.leading, CK.Space.m)
                    .padding(.trailing, isModified ? CK.Space.s : CK.Space.m)
                    .padding(.vertical, CK.Space.s + 4)
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title), \(summary)")
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand")

                if isModified {
                    Button(action: onReset) {
                        Text("Reset")
                            .font(CK.Font.label)
                            .foregroundStyle(CK.Palette.forest)
                            .padding(.horizontal, CK.Space.s + 2)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, CK.Space.s)
                    .accessibilityLabel("Reset \(title.lowercased()) to template")
                }
            }
            if isExpanded {
                Rectangle().fill(CK.Palette.hairline).frame(height: 0.5)
                VStack(alignment: .leading, spacing: CK.Space.l) {
                    content()
                }
                .padding(CK.Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
    }
}

/// Small title plus optional helper line above one control.
struct EdStyleLabel: View {
    let title: String
    var help: String = ""
    var trailing: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(CK.Font.label)
                    .foregroundStyle(CK.Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: CK.Space.s)
                if !trailing.isEmpty {
                    Text(trailing)
                        .font(CK.Font.caption.monospacedDigit())
                        .foregroundStyle(CK.Palette.graphite)
                        .accessibilityHidden(true)
                }
            }
            if !help.isEmpty {
                Text(help)
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Sample tiles

/// A choice drawn as a tiny page above a short label. The template's own choice carries a champagne dot.
struct EdSampleChip<Sample: View>: View {
    let label: String
    let selected: Bool
    var isTemplateChoice: Bool = false
    var tileWidth: CGFloat = 76
    var tileHeight: CGFloat = 52
    let action: () -> Void
    @ViewBuilder var sample: () -> Sample

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white)
                    sample()
                        .padding(7)
                        .frame(width: tileWidth, height: tileHeight, alignment: .topLeading)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    if isTemplateChoice {
                        Circle()
                            .fill(CK.Palette.champagne)
                            .frame(width: 6, height: 6)
                            .padding(4)
                    }
                }
                .frame(width: tileWidth, height: tileHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(selected ? CK.Palette.forest : CK.Palette.hairline, lineWidth: selected ? 2 : 0.75)
                )
                .shadow(color: Color.black.opacity(selected ? 0.10 : 0.04), radius: selected ? 6 : 3, y: 2)

                Text(label)
                    .font(CK.Font.caption.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? CK.Palette.forest : CK.Palette.ink)
                    .multilineTextAlignment(.center)
                    .frame(width: tileWidth + 8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(isTemplateChoice ? "Template default" : "")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
    }
}

/// Tiny drawing helpers used by the sample tiles. Purely decorative.
enum EdSampleInk {
    static let line = Color(hexString: "#C9C4BA")
    static let ink = Color(hexString: "#2A2E2B")

    static func bar(_ width: CGFloat, _ height: CGFloat = 3, _ color: Color = EdSampleInk.line) -> some View {
        Capsule().fill(color).frame(width: width, height: height)
    }

    /// Two grey text lines that stand for body copy.
    static func body(_ width: CGFloat = 52) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            bar(width)
            bar(width * 0.75)
        }
    }
}

struct EdDottedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - Choice chip (text)

/// Text-only choice chip, used for bullets, dates and photo shapes.
struct EdChoiceChip: View {
    let title: String
    var glyph: String = ""
    var accessibilityText: String = ""
    let selected: Bool
    var isTemplateChoice: Bool = false
    var accent: Color = CK.Palette.forest
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if !glyph.isEmpty {
                    Text(glyph)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(selected ? CK.Palette.onForest : accent)
                }
                Text(title)
                    .font(CK.Font.label)
                    .foregroundStyle(selected ? CK.Palette.onForest : CK.Palette.ink)
                if isTemplateChoice {
                    Circle()
                        .fill(CK.Palette.champagne)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 44)
            .background(Capsule().fill(selected ? CK.Palette.forest : CK.Palette.stone))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText.isEmpty ? title : accessibilityText)
        .accessibilityValue(isTemplateChoice ? "Template default" : "")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
    }
}

// MARK: - Colour row

struct EdSwatch: Hashable {
    let name: String
    let hex: String
}

/// Template chip, named swatches and a system colour picker for one colour override.
struct EdColorRow: View {
    let title: String
    var help: String = ""
    let swatches: [EdSwatch]
    @Binding var selection: String?
    let templateHex: String

    private var current: String { (selection ?? templateHex).uppercased() }

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            EdStyleLabel(title: title, help: help)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    templateButton
                    ForEach(swatches, id: \.self) { swatch in
                        swatchButton(swatch)
                    }
                    ColorPicker(selection: customBinding, supportsOpacity: false) {
                        EmptyView()
                    }
                    .labelsHidden()
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("\(title), choose any colour")
                    .accessibilityValue(current)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var templateButton: some View {
        let selected: Bool = selection == nil
        return Button { selection = nil } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hexString: templateHex))
                    .frame(width: 18, height: 18)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))
                Text("Template")
                    .font(CK.Font.label)
                    .foregroundStyle(selected ? CK.Palette.onForest : CK.Palette.ink)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(Capsule().fill(selected ? CK.Palette.forest : CK.Palette.stone))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), template colour")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
    }

    private func swatchButton(_ swatch: EdSwatch) -> some View {
        let selected: Bool = selection?.uppercased() == swatch.hex.uppercased()
        let checkColor: Color = Self.isLight(swatch.hex) ? Color.black : Color.white
        return Button { selection = swatch.hex } label: {
            Circle()
                .fill(Color(hexString: swatch.hex))
                .frame(width: 30, height: 30)
                .overlay(Circle().strokeBorder(Color.black.opacity(0.12), lineWidth: 0.5))
                .overlay {
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(checkColor)
                    }
                }
                .padding(5)
                .overlay(Circle().strokeBorder(selected ? CK.Palette.forest : Color.clear, lineWidth: 2))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(swatch.name)")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : [.isButton])
    }

    private var customBinding: Binding<Color> {
        Binding(
            get: { Color(hexString: current) },
            set: { selection = UIColor($0).hexString }
        )
    }

    /// Rough luminance check so the check mark stays visible on pale swatches.
    static func isLight(_ hex: String) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(hexString: hex).getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance: CGFloat = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6
    }
}

// MARK: - Slider row

struct EdStyleSlider: View {
    let title: String
    var help: String = ""
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            EdStyleLabel(title: title, help: help, trailing: valueText)
            Slider(value: $value, in: range, step: step)
                .tint(CK.Palette.forest)
                .frame(minHeight: 44)
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
        }
    }
}
