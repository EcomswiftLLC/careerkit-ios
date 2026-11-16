import SwiftUI

/// Illustrations for the five onboarding pages. They use the app's real templates and fonts
/// plus the drawn paper motif. Decorative only, so hidden from VoiceOver.
struct CKOnboardingArt: View {
    let index: Int
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        content
            .frame(height: 300)
            .scaleEffect(isActive ? 1 : 0.94)
            .opacity(isActive ? 1 : 0.6)
            .animation(
                reduceMotion ? nil : Animation.spring(response: 0.6, dampingFraction: 0.85),
                value: isActive
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch index {
        case 0: CKPaperStack(spread: isActive)
        case 1: createArt
        case 2: fanArt
        case 3: styleArt
        default: pairArt
        }
    }

    // MARK: Helpers

    private func template(at position: Int) -> TemplateSpec? {
        let all = TemplateLibrary.all
        return all.isEmpty ? nil : all[position % all.count]
    }

    @ViewBuilder
    private func thumb(_ position: Int, width: CGFloat) -> some View {
        if let spec = template(at: position) {
            TemplateThumbnail(template: spec, size: width)
                .frame(width: width, height: width * 1.414)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(CK.Palette.hairline, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        } else {
            CKPaperSheet(lineCount: 8).frame(width: width, height: width * 1.414)
        }
    }

    private func sectionChip(_ kind: SectionKind) -> some View {
        HStack(spacing: 6) {
            Image(systemName: kind.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CK.Palette.forest)
            Text(kind.defaultTitle)
                .font(CK.Font.caption.weight(.medium))
                .foregroundStyle(CK.Palette.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule(style: .continuous).fill(CK.Palette.surface))
        .overlay(Capsule(style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }

    // MARK: Pages

    private var createArt: some View {
        HStack(alignment: .center, spacing: -26) {
            thumb(0, width: 170)
            VStack(alignment: .leading, spacing: 12) {
                sectionChip(.experience)
                sectionChip(.education)
                sectionChip(.skills)
            }
            .offset(x: isActive ? 0 : 20)
        }
    }

    private var fanArt: some View {
        ZStack {
            thumb(9, width: 128)
                .rotationEffect(.degrees(isActive ? -10 : -2))
                .offset(x: isActive ? -74 : -10, y: 10)
            thumb(21, width: 128)
                .rotationEffect(.degrees(isActive ? 10 : 2))
                .offset(x: isActive ? 74 : 10, y: 10)
            thumb(3, width: 140)
        }
    }

    private var styleArt: some View {
        HStack(alignment: .center, spacing: CK.Space.l) {
            thumb(14, width: 150)
            VStack(alignment: .leading, spacing: CK.Space.m) {
                HStack(spacing: 8) {
                    ForEach(["#1F4D3A", "#1F3A5F", "#7A2E3A", "#2B2B2B", "#B89B5E"], id: \.self) { hex in
                        Circle()
                            .fill(Color(hexString: hex))
                            .frame(width: 24, height: 24)
                            .overlay(Circle().strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    fontSample(.georgia)
                    fontSample(.avenirNext)
                    fontSample(.didot)
                }
            }
        }
    }

    private func fontSample(_ choice: FontChoice) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Aa")
                .font(Font.custom(choice.familyName ?? choice.displayName, size: 28))
                .foregroundStyle(CK.Palette.ink)
            Text(choice.displayName)
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)
        }
    }

    private var pairArt: some View {
        let matchPosition = 5
        return ZStack {
            CKPaperSheet(lineCount: 9, accent: CK.Palette.champagne)
                .frame(width: 138, height: 190)
                .rotationEffect(.degrees(isActive ? 7 : 1))
                .offset(x: isActive ? 66 : 20, y: 14)
            thumb(matchPosition, width: 144)
                .rotationEffect(.degrees(isActive ? -5 : -1))
                .offset(x: isActive ? -50 : -14, y: 0)
        }
    }
}
