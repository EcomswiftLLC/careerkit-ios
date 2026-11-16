import SwiftUI

/// Sheet with every resume template. Choosing one only changes the layout; the content is untouched.
struct TemplateSwitcherSheet: View {
    let currentID: String
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var category: TemplateCategory?

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
                chip(title: "All", selected: category == nil) { category = nil }
                ForEach(TemplateCategory.allCases) { item in
                    chip(title: item.rawValue, selected: category == item) { category = item }
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
        let isCurrent = template.id == currentID
        return Button {
            onSelect(template.id)
            dismiss()
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
                        .lineLimit(1)
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
                if template.isATSFriendly {
                    Text("Plain layout")
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.forest)
                }
            }
            .frame(width: 150, alignment: .leading)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(template.name). \(template.tagline)")
        .accessibilityValue(isCurrent ? "Current template" : "")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}
