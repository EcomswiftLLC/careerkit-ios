import SwiftUI

// Small building blocks shared by the editor, cover letter and builder screens.
// Prefixed `Ed` so they cannot collide with the app shell's components.

// MARK: - Text fields

/// Label above, plain text field, hairline below. Reads as a printed form rather than a settings list.
struct EdField: View {
    let label: String
    @Binding var text: String
    var prompt: String = ""
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var capitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)
                .accessibilityHidden(true)
            TextField(label, text: $text, prompt: Text(prompt.isEmpty ? label : prompt).foregroundColor(CK.Palette.graphite.opacity(0.6)))
                .font(CK.Font.body)
                .foregroundStyle(CK.Palette.ink)
                .keyboardType(keyboard)
                .textContentType(contentType)
                .textInputAutocapitalization(capitalization)
                .autocorrectionDisabled(keyboard != .default)
                .frame(minHeight: 36)
            Rectangle().fill(CK.Palette.hairline).frame(height: 1)
        }
    }
}

/// Multi-line text area with a placeholder.
struct EdTextArea: View {
    var label: String = ""
    @Binding var text: String
    var prompt: String = ""
    var minHeight: CGFloat = 120

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !label.isEmpty {
                Text(label)
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .accessibilityHidden(true)
            }
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .scrollContentBackground(.hidden)
                    .font(CK.Font.body)
                    .foregroundStyle(CK.Palette.ink)
                    .frame(minHeight: minHeight)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .accessibilityLabel(label.isEmpty ? prompt : label)
                if text.isEmpty && !prompt.isEmpty {
                    Text(prompt)
                        .font(CK.Font.body)
                        .foregroundStyle(CK.Palette.graphite.opacity(0.6))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .background(RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous).fill(CK.Palette.ivory))
            .overlay(RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 1))
        }
    }
}

// MARK: - Card

/// Collapsible card: serif title, a plain status line, hairline border. Optional trailing accessory (menu, badge).
struct EdDisclosureCard<Accessory: View, Content: View>: View {
    let title: String
    var subtitle: String = ""
    var systemImage: String? = nil
    var dimmed: Bool = false
    @Binding var isExpanded: Bool
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: CK.Space.s + 4) {
                        if let systemImage {
                            Image(systemName: systemImage)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(CK.Palette.forest)
                                .frame(width: 24)
                                .accessibilityHidden(true)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(CK.Font.headline(18))
                                .foregroundStyle(CK.Palette.ink)
                                .multilineTextAlignment(.leading)
                            if !subtitle.isEmpty {
                                Text(subtitle)
                                    .font(CK.Font.caption)
                                    .foregroundStyle(CK.Palette.graphite)
                            }
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CK.Palette.graphite)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            .accessibilityHidden(true)
                    }
                    .padding(.leading, CK.Space.m)
                    .padding(.vertical, CK.Space.s + 4)
                    .frame(minHeight: 56)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(subtitle.isEmpty ? title : "\(title), \(subtitle)")
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand")")
                accessory()
                    .padding(.trailing, CK.Space.s)
            }
            if isExpanded {
                Rectangle().fill(CK.Palette.hairline).frame(height: 0.5)
                VStack(alignment: .leading, spacing: CK.Space.m) {
                    content()
                }
                .padding(CK.Space.m)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
        .opacity(dimmed ? 0.72 : 1)
    }
}

extension EdDisclosureCard where Accessory == EmptyView {
    init(title: String, subtitle: String = "", systemImage: String? = nil, dimmed: Bool = false,
         isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.dimmed = dimmed
        self._isExpanded = isExpanded
        self.accessory = { EmptyView() }
        self.content = content
    }
}

// MARK: - Buttons

/// Quiet text button with an icon, 44 pt tall.
struct EdTextButton: View {
    let title: String
    var systemImage: String? = nil
    var role: ButtonRole? = nil
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.system(size: 14, weight: .medium)) }
                Text(title).font(CK.Font.label)
            }
            .foregroundStyle(role == .destructive ? CK.Palette.danger : CK.Palette.forest)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Ellipsis menu button with a 44 pt target.
struct EdMoreMenu<MenuContent: View>: View {
    var label: String = "More actions"
    @ViewBuilder var content: () -> MenuContent

    var body: some View {
        Menu {
            content()
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(CK.Palette.graphite)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
    }
}

// MARK: - Status and mode

struct EdSaveIndicator: View {
    let state: DocumentStore.SaveState

    var body: some View {
        Group {
            switch state {
            case .idle:
                Text(" ").font(CK.Font.caption)
            case .saving:
                Text("Saving").font(CK.Font.caption).foregroundStyle(CK.Palette.graphite)
            case .saved:
                Label("Saved", systemImage: "checkmark")
                    .labelStyle(.titleAndIcon)
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
            case .failed:
                Label("Not saved", systemImage: "exclamationmark.triangle")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.danger)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

enum EditorMode: String, CaseIterable, Identifiable {
    case edit = "Edit"
    case preview = "Preview"
    var id: String { rawValue }
}

/// Two-segment switch with a sliding forest highlight.
struct EdModeSwitch: View {
    @Binding var mode: EditorMode
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(EditorMode.allCases) { item in
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { mode = item }
                } label: {
                    Text(item.rawValue)
                        .font(CK.Font.label)
                        .foregroundStyle(mode == item ? CK.Palette.onForest : CK.Palette.ink)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if mode == item {
                                Capsule().fill(CK.Palette.forest).matchedGeometryEffect(id: "mode", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(mode == item ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Capsule().fill(CK.Palette.stone))
        .frame(maxWidth: 260)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Editor mode")
    }
}

// MARK: - Flow layout for tokens

struct EdFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }
        return CGSize(width: usedWidth, height: subviews.isEmpty ? 0 : y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
