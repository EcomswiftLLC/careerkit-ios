import SwiftUI

// MARK: - Adaptive grid that tells each cell how wide it is

/// Lays items out in fixed-width columns sized from the available width, so thumbnails
/// (which need an explicit size) always fill the row evenly on iPhone and iPad.
struct CKAdaptiveGrid<Item: Identifiable, Cell: View>: View {
    let items: [Item]
    var minWidth: CGFloat
    var spacing: CGFloat
    let cell: (Item, CGFloat) -> Cell

    @State private var available: CGFloat = 0

    init(
        items: [Item],
        minWidth: CGFloat = 156,
        spacing: CGFloat = 16,
        @ViewBuilder cell: @escaping (Item, CGFloat) -> Cell
    ) {
        self.items = items
        self.minWidth = minWidth
        self.spacing = spacing
        self.cell = cell
    }

    private var columnCount: Int {
        guard available > 0 else { return 2 }
        return max(2, Int((available + spacing) / (minWidth + spacing)))
    }

    private var cellWidth: CGFloat {
        guard available > 0 else { return minWidth }
        let total = available - spacing * CGFloat(columnCount - 1)
        return max(100, floor(total / CGFloat(columnCount)))
    }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 0)
                .ckReadWidth($available)
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.fixed(cellWidth), spacing: spacing, alignment: .top),
                    count: columnCount
                ),
                alignment: .leading,
                spacing: spacing + 8
            ) {
                ForEach(items) { item in
                    cell(item, cellWidth)
                }
            }
        }
    }
}

// MARK: - ATS badge

struct CKATSBadge: View {
    var compact = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: compact ? 11 : 13, weight: .semibold))
            Text("ATS friendly")
                .font(compact ? CK.Font.overline.weight(.semibold) : CK.Font.caption.weight(.semibold))
        }
        .foregroundStyle(CK.Palette.forest)
        .padding(.horizontal, compact ? 7 : 10)
        .padding(.vertical, compact ? 3 : 5)
        .background(Capsule(style: .continuous).fill(CK.Palette.forest.opacity(0.10)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("ATS friendly layout"))
    }
}

// MARK: - Template card

/// Thumbnail comes from the editor owner's `TemplateThumbnail`. `width` is passed as its `size`.
struct CKTemplateCard: View {
    let template: TemplateSpec
    var width: CGFloat
    var isSelected = false
    var showsDetails = true
    let action: () -> Void

    private var pagesLabel: String {
        template.typicalPages <= 1 ? String(localized: "1 page") : String(localized: "\(template.typicalPages) pages")
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: CK.Space.s + 2) {
                TemplateThumbnail(template: template, size: width)
                    .frame(width: width, height: width * 1.414)
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(isSelected ? CK.Palette.forest : CK.Palette.hairline,
                                          lineWidth: isSelected ? 2 : 0.5)
                    )
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(CK.Palette.forest, CK.Palette.surface)
                                .padding(6)
                        }
                    }
                    .shadow(color: .black.opacity(0.09), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(template.name)
                        .font(CK.Font.headline(16))
                        .foregroundStyle(CK.Palette.ink)
                        .lineLimit(1)
                    if showsDetails {
                        Text(template.tagline)
                            .font(CK.Font.caption)
                            .foregroundStyle(CK.Palette.graphite)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 6) {
                            if template.isATSFriendly { CKATSBadge(compact: true) }
                            Text(pagesLabel)
                                .font(CK.Font.caption)
                                .foregroundStyle(CK.Palette.graphite)
                        }
                        .padding(.top, 2)
                    }
                }
                .frame(width: width, alignment: .leading)
            }
            .frame(width: width, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var accessibilityText: String {
        var parts = [template.name, template.tagline, pagesLabel]
        if template.isATSFriendly { parts.append(String(localized: "ATS friendly")) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Filter chips

/// Single-choice chip row. For an optional filter pass `[nil] + values.map(Optional.some)`
/// as `options` and map `nil` to "All" in `title`.
struct CKFilterChipBar<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CK.Space.s) {
                ForEach(options, id: \.self) { option in
                    chip(for: option)
                }
            }
            .padding(.horizontal, CK.Space.m)
        }
    }

    private func chip(for option: Option) -> some View {
        let selected = option == selection
        return Button {
            selection = option
        } label: {
            Text(title(option))
                .font(CK.Font.label)
                .foregroundStyle(selected ? CK.Palette.onForest : CK.Palette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 36)
                .background(Capsule(style: .continuous).fill(selected ? CK.Palette.forest : CK.Palette.surface))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(selected ? Color.clear : CK.Palette.hairline, lineWidth: 1)
                )
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A chip that opens a menu of choices. `selection == nil` means "any".
struct CKFilterMenuChip<Option: Hashable>: View {
    let name: String
    let options: [Option]
    @Binding var selection: Option?
    let title: (Option) -> String

    var body: some View {
        Menu {
            Button { selection = nil } label: {
                if selection == nil {
                    Label("Any", systemImage: "checkmark")
                } else {
                    Text("Any")
                }
            }
            ForEach(options, id: \.self) { option in
                Button { selection = option } label: {
                    if selection == option {
                        Label(title(option), systemImage: "checkmark")
                    } else {
                        Text(title(option))
                    }
                }
            }
        } label: {
            CKChipLabel(
                text: selection.map(title) ?? name,
                isActive: selection != nil,
                showsChevron: true
            )
        }
        .accessibilityLabel(Text(name))
        .accessibilityValue(Text(selection.map(title) ?? String(localized: "Any")))
    }
}

/// An on / off chip.
struct CKToggleChip: View {
    let name: String
    var systemImage: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        Button { isOn.toggle() } label: {
            CKChipLabel(text: name, isActive: isOn, showsChevron: false, systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

struct CKChipLabel: View {
    let text: String
    var isActive: Bool
    var showsChevron: Bool
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 12, weight: .semibold))
            }
            Text(text).font(CK.Font.label)
            if showsChevron {
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
            }
        }
        .foregroundStyle(isActive ? CK.Palette.forest : CK.Palette.ink)
        .padding(.horizontal, 14)
        .frame(minHeight: 36)
        .background(
            Capsule(style: .continuous)
                .fill(isActive ? CK.Palette.forest.opacity(0.10) : CK.Palette.surface)
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(isActive ? CK.Palette.forest : CK.Palette.hairline, lineWidth: 1)
        )
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}
