import SwiftUI
import UIKit

// MARK: - Width measuring

struct CKWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension View {
    /// Writes the width this view is laid out at into `width`. Used to size grids and columns.
    func ckReadWidth(_ width: Binding<CGFloat>) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(key: CKWidthKey.self, value: proxy.size.width)
            }
        )
        .onPreferenceChange(CKWidthKey.self) { value in
            if abs(width.wrappedValue - value) > 0.5 {
                width.wrappedValue = value
            }
        }
    }
}

// MARK: - Dynamic Type aware serif fonts

private struct CKTitleModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat

    init(base: CGFloat) {
        _size = ScaledMetric(wrappedValue: base, relativeTo: .title)
    }

    func body(content: Content) -> some View {
        content
            // `size` is already scaled by @ScaledMetric, so the fixed-size system font is used here
            // (CK.Font.title would scale a second time).
            .font(.system(size: size, weight: .semibold, design: .serif))
            .foregroundStyle(CK.Palette.ink)
    }
}

private struct CKHeadlineModifier: ViewModifier {
    @ScaledMetric private var size: CGFloat

    init(base: CGFloat) {
        _size = ScaledMetric(wrappedValue: base, relativeTo: .headline)
    }

    func body(content: Content) -> some View {
        content
            .font(.system(size: size, weight: .semibold, design: .serif))
            .foregroundStyle(CK.Palette.ink)
    }
}

extension View {
    /// Editorial serif title that scales with Dynamic Type.
    func ckTitle(_ base: CGFloat = 30) -> some View { modifier(CKTitleModifier(base: base)) }
    /// Smaller serif heading that scales with Dynamic Type.
    func ckHeadline(_ base: CGFloat = 19) -> some View { modifier(CKHeadlineModifier(base: base)) }
}

// MARK: - Small helpers

enum CKDate {
    static func relative(_ date: Date, now: Date = Date()) -> String {
        if abs(now.timeIntervalSince(date)) < 60 { return String(localized: "just now") }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    static func edited(_ date: Date) -> String {
        let when = relative(date)
        return String(localized: "Edited \(when)")
    }
}

enum CKDeferred {
    /// Runs `work` shortly after a sheet has finished dismissing, so a push or a second
    /// presentation does not collide with the dismissal.
    static func afterDismiss(_ work: @escaping @MainActor () -> Void) {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            work()
        }
    }
}

struct CKUUIDItem: Identifiable, Hashable {
    let id: UUID
}

struct CKHairline: View {
    var body: some View {
        Rectangle()
            .fill(CK.Palette.hairline)
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }
}

// MARK: - Section header

struct CKSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CK.Space.m) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .ckHeadline(21)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.graphite)
                }
            }
            Spacer(minLength: CK.Space.s)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(CK.Font.label)
                        .foregroundStyle(CK.Palette.forest)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Paper artwork (drawn, not placeholder: a stylised document sheet)

struct CKPaperSheet: View {
    var lineCount: Int = 7
    var accent: Color = CK.Palette.forest

    private let widths: [CGFloat] = [0.92, 0.78, 0.86, 0.6, 0.82, 0.7, 0.88, 0.5, 0.74]

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: geo.size.height * 0.05) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accent.opacity(0.9))
                    .frame(width: geo.size.width * 0.5, height: max(4, geo.size.height * 0.045))
                Rectangle()
                    .fill(CK.Palette.hairline)
                    .frame(height: 1)
                ForEach(0..<lineCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(CK.Palette.stone)
                        .frame(
                            width: geo.size.width * 0.84 * widths[index % widths.count],
                            height: max(3, geo.size.height * 0.028)
                        )
                }
                Spacer(minLength: 0)
            }
            .padding(geo.size.width * 0.1)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous).fill(CK.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(CK.Palette.hairline, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
        .accessibilityHidden(true)
    }
}

/// A single sheet with a round forest badge, for compact empty states.
struct CKPaperGlyph: View {
    var systemImage: String = "doc.text"

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            CKPaperSheet(lineCount: 6)
                .frame(width: 88, height: 116)
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CK.Palette.onForest)
                .frame(width: 40, height: 40)
                .background(Circle().fill(CK.Palette.forest))
                .overlay(Circle().strokeBorder(CK.Palette.ivory, lineWidth: 3))
                .offset(x: 16, y: 12)
        }
        .padding(.trailing, 16)
        .padding(.bottom, 12)
        .accessibilityHidden(true)
    }
}

/// Three sheets that fan out when `spread` becomes true. The caller decides how to animate.
struct CKPaperStack: View {
    var spread: Bool

    var body: some View {
        ZStack {
            CKPaperSheet(lineCount: 5, accent: CK.Palette.champagne)
                .frame(width: 128, height: 170)
                .rotationEffect(.degrees(spread ? -9 : -2))
                .offset(x: spread ? -48 : -8, y: 8)
            CKPaperSheet(lineCount: 5, accent: CK.Palette.graphite)
                .frame(width: 128, height: 170)
                .rotationEffect(.degrees(spread ? 8 : 2))
                .offset(x: spread ? 48 : 8, y: 10)
            CKPaperSheet(lineCount: 8)
                .frame(width: 136, height: 180)
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(CK.Palette.onForest)
                .frame(width: 38, height: 38)
                .background(Circle().fill(CK.Palette.forest))
                .overlay(Circle().strokeBorder(CK.Palette.ivory, lineWidth: 3))
                .offset(x: 62, y: 80)
        }
        .frame(height: 210)
        .accessibilityHidden(true)
    }
}

// MARK: - Empty state

struct CKEmptyState: View {
    let title: String
    let message: String
    var systemImage: String = "doc.text"
    var primaryTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: CK.Space.l) {
            CKPaperGlyph(systemImage: systemImage)
            VStack(spacing: CK.Space.s) {
                Text(title)
                    .ckTitle(24)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.graphite)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if primaryTitle != nil || secondaryTitle != nil {
                VStack(spacing: CK.Space.s + 4) {
                    if let primaryTitle, let primaryAction {
                        Button(primaryTitle, action: primaryAction)
                            .buttonStyle(.ckPrimary)
                    }
                    if let secondaryTitle, let secondaryAction {
                        Button(secondaryTitle, action: secondaryAction)
                            .buttonStyle(.ckSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: 420)
        .padding(CK.Space.l)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Toast

private struct CKToastModifier: ViewModifier {
    @Binding var message: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dismissTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let text = message {
                    Text(text)
                        .font(CK.Font.label)
                        .foregroundStyle(CK.Palette.ivory)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(CK.Palette.ink)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                        .padding(.horizontal, CK.Space.l)
                        .padding(.bottom, CK.Space.l)
                        .transition(
                            reduceMotion
                                ? AnyTransition.opacity
                                : AnyTransition.move(edge: .bottom).combined(with: .opacity)
                        )
                }
            }
            .animation(reduceMotion ? nil : Animation.easeOut(duration: 0.25), value: message)
            .onChange(of: message) { _, newValue in
                schedule(newValue)
            }
    }

    private func schedule(_ text: String?) {
        dismissTask?.cancel()
        guard let text else { return }
        UIAccessibility.post(notification: .announcement, argument: text)
        dismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            if !Task.isCancelled { message = nil }
        }
    }
}

extension View {
    /// Shows a short message at the bottom of the screen. Set the binding to a string to show it.
    func ckToast(_ message: Binding<String?>) -> some View {
        modifier(CKToastModifier(message: message))
    }
}

// MARK: - Share sheet

struct CKShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct CKShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
