import SwiftUI

/// The Photo group of the style panel: show or hide, shape, size, border and side.
/// Every choice is stored in `StyleOverrides`; nil keeps the template's own behaviour.
struct EdPhotoStyleGroup: View {
    @Binding var style: StyleOverrides
    /// The resume template. nil hides the template specific rows.
    let template: TemplateSpec?
    @Binding var isExpanded: Bool

    private var supportsPhoto: Bool { template?.supportsPhoto ?? false }

    private var effectiveTemplate: TemplateSpec? {
        guard let template else { return nil }
        return template.applying(style)
    }

    /// The side switch only shows when the current header has a photo slot on both sides.
    private var canFlip: Bool {
        guard let effective = effectiveTemplate else { return false }
        return effective.supportsPhotoFlip
    }

    private var currentSide: SidebarPosition {
        if let side = style.photoSide { return side }
        return template?.photo == .headerLeft ? .left : .right
    }

    private var templateSide: SidebarPosition {
        return template?.photo == .headerLeft ? .left : .right
    }

    private var isModified: Bool {
        !style.showPhoto || style.photoShape != nil || style.photoSize != nil || style.photoBorder != nil || style.photoSide != nil
    }

    private var summary: String {
        if !supportsPhoto { return String(localized: "This template has no photo area") }
        return style.showPhoto ? String(localized: "Shown") : String(localized: "Hidden")
    }

    var body: some View {
        EdStyleGroup(title: String(localized: "Photo"),
                     summary: summary,
                     systemImage: "person.crop.circle",
                     isModified: isModified,
                     onReset: {
                         style.showPhoto = true
                         style.photoShape = nil
                         style.photoSize = nil
                         style.photoBorder = nil
                         style.photoSide = nil
                     },
                     isExpanded: $isExpanded) {
            if !supportsPhoto {
                Text("This template is built without a photo, which suits applications where a photo is not expected. Your photo is kept and shows again on templates with a photo area.")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Toggle(isOn: $style.showPhoto) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show photo").font(CK.Font.body).foregroundStyle(CK.Palette.ink)
                    Text("Only templates with a photo area use it. Many employers prefer resumes without one.")
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(CK.Palette.forest)
            .frame(minHeight: 44)

            VStack(alignment: .leading, spacing: CK.Space.m) {
                shapeRow
                sizeRow
                borderRow
                if canFlip {
                    sideRow
                }
            }
            .disabled(!style.showPhoto || !supportsPhoto)
            .opacity(style.showPhoto && supportsPhoto ? 1 : 0.5)
        }
    }

    private var shapeRow: some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            EdStyleLabel(title: String(localized: "Photo shape"))
            EdFlowLayout(spacing: CK.Space.s) {
                EdChoiceChip(title: String(localized: "Template"), accessibilityText: String(localized: "Template photo shape"),
                             selected: style.photoShape == nil) { style.photoShape = nil }
                ForEach(PhotoShape.allCases) { shape in
                    EdChoiceChip(title: EdStyleNames.photoShape(shape),
                                 selected: style.photoShape == shape) { style.photoShape = shape }
                }
            }
        }
    }

    private var sizeRow: some View {
        let current: PhotoSizeOption = style.photoSize ?? .medium
        return VStack(alignment: .leading, spacing: CK.Space.s) {
            EdStyleLabel(title: String(localized: "Photo size"))
            EdFlowLayout(spacing: CK.Space.s) {
                ForEach(PhotoSizeOption.allCases) { option in
                    EdChoiceChip(title: EdStyleNames.photoSize(option),
                                 accessibilityText: String(localized: "Photo size \(EdStyleNames.photoSize(option))"),
                                 selected: current == option,
                                 isTemplateChoice: option == .medium) {
                        style.photoSize = option == .medium ? nil : option
                    }
                }
            }
        }
    }

    private var borderRow: some View {
        let current: PhotoBorderOption = style.photoBorder ?? .none
        return VStack(alignment: .leading, spacing: CK.Space.s) {
            EdStyleLabel(title: String(localized: "Photo border"), help: String(localized: "A thin ring in the accent color."))
            EdFlowLayout(spacing: CK.Space.s) {
                ForEach(PhotoBorderOption.allCases) { option in
                    EdChoiceChip(title: EdStyleNames.photoBorder(option),
                                 accessibilityText: String(localized: "Photo border \(EdStyleNames.photoBorder(option))"),
                                 selected: current == option,
                                 isTemplateChoice: option == .none) {
                        style.photoBorder = option == .none ? nil : option
                    }
                }
            }
        }
    }

    private var sideRow: some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            EdStyleLabel(title: String(localized: "Photo side"))
            EdFlowLayout(spacing: CK.Space.s) {
                ForEach(SidebarPosition.allCases) { side in
                    EdChoiceChip(title: side == .left ? String(localized: "Left") : String(localized: "Right"),
                                 accessibilityText: side == .left ? String(localized: "Photo on the left") : String(localized: "Photo on the right"),
                                 selected: currentSide == side,
                                 isTemplateChoice: side == templateSide) {
                        style.photoSide = side == templateSide ? nil : side
                    }
                }
            }
        }
    }
}
