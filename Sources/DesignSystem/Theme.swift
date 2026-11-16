import SwiftUI
import UIKit

// MARK: - Colour tokens

/// Warm ivory / charcoal / forest green palette with matching dark mode.
enum CK {
    enum Palette {
        static let ivory      = dynamic(light: 0xFAF7F0, dark: 0x141614)
        static let surface    = dynamic(light: 0xFFFFFF, dark: 0x1D201E)
        static let stone      = dynamic(light: 0xECE7DC, dark: 0x262A27)
        static let hairline   = dynamic(light: 0xDDD6C8, dark: 0x343935)
        static let ink        = dynamic(light: 0x1F2421, dark: 0xF2EFE8)
        static let graphite   = dynamic(light: 0x5B605C, dark: 0xA9ADA8)
        static let forest     = dynamic(light: 0x1F4D3A, dark: 0x6FB594)
        static let forestDeep = dynamic(light: 0x16382A, dark: 0x4C9677)
        static let champagne  = dynamic(light: 0xB89B5E, dark: 0xCDB27A)
        static let danger     = dynamic(light: 0xA33A2F, dark: 0xE28A80)
        static let onForest   = dynamic(light: 0xFFFFFF, dark: 0x0F1A14)

        static func dynamic(light: UInt32, dark: UInt32) -> Color {
            Color(UIColor { trait in
                UIColor(hex: trait.userInterfaceStyle == .dark ? dark : light)
            })
        }
    }

    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum Radius {
        static let chip: CGFloat = 10
        static let card: CGFloat = 18
        static let sheet: CGFloat = 28
    }

    enum Font {
        /// Editorial serif for titles (New York), scales with Dynamic Type.
        static func title(_ size: CGFloat = 30) -> SwiftUI.Font {
            .system(size: size, weight: .semibold, design: .serif)
        }
        static func headline(_ size: CGFloat = 19) -> SwiftUI.Font {
            .system(size: size, weight: .semibold, design: .serif)
        }
        static let body = SwiftUI.Font.system(.body, design: .default)
        static let callout = SwiftUI.Font.system(.callout, design: .default)
        static let label = SwiftUI.Font.system(.subheadline, design: .default).weight(.medium)
        static let caption = SwiftUI.Font.system(.caption, design: .default)
        static let overline = SwiftUI.Font.system(.caption2, design: .default).weight(.semibold)
    }
}

// MARK: - UIColor / Color hex helpers (shared with the renderer)

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// Accepts "#RRGGBB" or "RRGGBB". Falls back to black on bad input.
    convenience init(hexString: String) {
        let cleaned = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "# ")).uppercased()
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(hex: UInt32(truncatingIfNeeded: value))
    }

    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(round(r * 255)), Int(round(g * 255)), Int(round(b * 255)))
    }
}

extension Color {
    init(hexString: String) { self.init(UIColor(hexString: hexString)) }
}

// MARK: - Reusable components

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CK.Font.label)
            .foregroundStyle(CK.Palette.onForest)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: CK.Radius.chip + 4, style: .continuous)
                    .fill(isEnabled ? CK.Palette.forest : CK.Palette.graphite.opacity(0.4))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(CK.Font.label)
            .foregroundStyle(CK.Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(
                RoundedRectangle(cornerRadius: CK.Radius.chip + 4, style: .continuous)
                    .strokeBorder(CK.Palette.hairline, lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: CK.Radius.chip + 4, style: .continuous)
                            .fill(CK.Palette.surface)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var ckPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var ckSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

struct CardModifier: ViewModifier {
    var padding: CGFloat = CK.Space.m
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous)
                    .fill(CK.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous)
                    .strokeBorder(CK.Palette.hairline, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }
}

extension View {
    func ckCard(padding: CGFloat = CK.Space.m) -> some View { modifier(CardModifier(padding: padding)) }

    /// Standard screen background.
    func ckScreen() -> some View {
        self.background(CK.Palette.ivory.ignoresSafeArea())
    }
}

struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(CK.Font.headline())
            .foregroundStyle(CK.Palette.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

struct Overline: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(CK.Font.overline)
            .tracking(1.2)
            .foregroundStyle(CK.Palette.graphite)
    }
}

struct ProgressRing: View {
    let value: Double   // 0...1
    var size: CGFloat = 44
    var lineWidth: CGFloat = 4
    var body: some View {
        ZStack {
            Circle().stroke(CK.Palette.stone, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, value)))
                .stroke(CK.Palette.forest, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: value)
            Text("\(Int(value * 100))%")
                .font(.system(size: size * 0.26, weight: .semibold))
                .foregroundStyle(CK.Palette.ink)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Completion")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}
