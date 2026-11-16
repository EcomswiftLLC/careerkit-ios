import SwiftUI
import UIKit

/// Sheet with every resume template. Choosing one only changes the layout; the content is untouched.
struct TemplateSwitcherSheet: View {
    let currentID: String
    /// True when the resume has a photo, so a switch to a template without a photo area can say it is hidden.
    var hasPhoto: Bool = false
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category: TemplateCategory?
    /// Set after picking a template without a photo area while the resume has a photo.
    @State private var hiddenPhotoNote: String?
    @State private var pickedID: String?

    private var templates: [TemplateSpec] {
        guard let category else { return TemplateLibrary.all }
        return TemplateLibrary.all.filter { $0.category == category }
    }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: CK.Space.m, alignment: .top)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CK.Space.m) {
                    Text("Switching templates changes the look only. Your text, sections and photo stay as they are.")
                        .font(CK.Font.callout)
                        .foregroundStyle(CK.Palette.graphite)
                    if let note = hiddenPhotoNote {
                        HStack(spacing: CK.Space.s) {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(CK.Palette.graphite)
                                .accessibilityHidden(true)
                            Text(note)
                                .font(CK.Font.caption)
                                .foregroundStyle(CK.Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, CK.Space.m)
                        .padding(.vertical, CK.Space.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: CK.Radius.chip, style: .continuous).fill(CK.Palette.stone))
                        .accessibilityElement(children: .combine)
                    }
                    filterChips
                    LazyVGrid(columns: columns, spacing: CK.Space.l) {
                        ForEach(templates) { template in
                            card(template)
                        }
                    }
                }
                .padding(CK.Space.m)
            }
            .background(CK.Palette.ivory.ignoresSafeArea())
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.font(CK.Font.label)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CK.Space.s) {
                chip(title: String(localized: "All"), selected: category == nil) { category = nil }
                ForEach(TemplateCategory.allCases) { item in
                    chip(title: item.displayName, selected: category == item) { category = item }
                }
            }
        }
    }

    private func chip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(CK.Font.label)
                .foregroundStyle(selected ? CK.Palette.onForest : CK.Palette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Capsule().fill(selected ? CK.Palette.forest : CK.Palette.stone))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func card(_ template: TemplateSpec) -> some View {
        let isCurrent = template.id == (pickedID ?? currentID)
        return Button {
            onSelect(template.id)
            if hasPhoto && !template.supportsPhoto {
                // Stay open for a moment so the note can be read; Done closes the sheet.
                pickedID = template.id
                let note = String(localized: "Your photo is kept but hidden, because \(template.name) has no photo area.")
                hiddenPhotoNote = note
                UIAccessibility.post(notification: .announcement, argument: note)
            } else {
                dismiss()
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                TemplateThumbnail(template: template, size: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(isCurrent ? CK.Palette.forest : Color.clear, lineWidth: 2)
                    )
                HStack(spacing: 4) {
                    Text(template.name)
                        .ckHeadlineFont(15)
                        .foregroundStyle(CK.Palette.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.leading)
                    if isCurrent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(CK.Palette.forest)
                            .accessibilityHidden(true)
                    }
                }
                Text(template.tagline)
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    if template.isATSFriendly {
                        Text("Plain layout")
                            .font(CK.Font.caption)
                            .foregroundStyle(CK.Palette.forest)
                    }
                    if template.supportsPhoto {
                        CKPhotoBadge(compact: true)
                    }
                }
            }
            .frame(width: 150, alignment: .leading)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(cardLabel(template)))
        .accessibilityValue(isCurrent ? String(localized: "Current template") : "")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func cardLabel(_ template: TemplateSpec) -> String {
        if template.supportsPhoto {
            return String(localized: "\(template.name). \(template.tagline). Has a photo area.")
        }
        return "\(template.name). \(template.tagline)"
    }
}
