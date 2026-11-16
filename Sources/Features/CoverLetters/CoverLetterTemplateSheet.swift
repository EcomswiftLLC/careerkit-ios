import SwiftUI

/// Grid of the cover letter templates with sample previews. Used by the editor's template switcher
/// and by the "new cover letter" sheet.
struct CoverLetterTemplateGrid: View {
    let selectedID: String
    let onSelect: (String) -> Void

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: CK.Space.m, alignment: .top)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: CK.Space.l) {
            ForEach(CoverLetterTemplateLibrary.all) { template in
                let isSelected = template.id == selectedID
                Button { onSelect(template.id) } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        CoverLetterThumbnail(template: template, size: 150)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(isSelected ? CK.Palette.forest : Color.clear, lineWidth: 2)
                            )
                        HStack(spacing: 4) {
                            Text(template.name)
                                .ckHeadlineFont(15)
                                .foregroundStyle(CK.Palette.ink)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)
                            if isSelected {
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
                    }
                    .frame(width: 150, alignment: .leading)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(template.name). \(template.tagline)")
                .accessibilityValue(Text(isSelected ? String(localized: "Selected") : ""))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

struct CoverLetterTemplateSheet: View {
    let currentID: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CK.Space.m) {
                    Text("Switching templates changes the look only. Your text stays as it is.")
                        .font(CK.Font.callout)
                        .foregroundStyle(CK.Palette.graphite)
                    CoverLetterTemplateGrid(selectedID: currentID) { id in
                        onSelect(id)
                        dismiss()
                    }
                }
                .padding(CK.Space.m)
            }
            .background(CK.Palette.ivory.ignoresSafeArea())
            .navigationTitle("Letter templates")
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
}
