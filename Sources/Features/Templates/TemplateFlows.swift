import SwiftUI

extension View {
    /// Presents the blank-resume flow (no template) and reports the new resume id after the sheet is gone.
    func ckBlankResumeSheet(isPresented: Binding<Bool>, onCreated: @escaping (UUID) -> Void) -> some View {
        sheet(isPresented: isPresented) {
            NewResumeFlow(templateID: nil, onCreated: { newID in
                isPresented.wrappedValue = false
                CKDeferred.afterDismiss { onCreated(newID) }
            })
        }
    }

    /// Presents the large template preview. "Use This Template" runs `NewResumeFlow`, and once the
    /// resume exists both sheets close and `onCreated` runs so the caller can open the editor.
    func templatePreviewSheet(_ template: Binding<TemplateSpec?>, onCreated: @escaping (UUID) -> Void) -> some View {
        sheet(item: template) { spec in
            CKTemplatePreviewSheet(template: spec, onCreated: { newID in
                template.wrappedValue = nil
                CKDeferred.afterDismiss { onCreated(newID) }
            })
        }
    }
}

/// Picks a template for an existing resume. Content stays; only the design changes.
struct CKTemplatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let currentTemplateID: String
    let onPick: (String) -> Void

    @State private var filter = CKTemplateFilter()

    private var results: [TemplateSpec] {
        filter.apply(to: TemplateLibrary.all)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CK.Space.m) {
                    Text("Your text stays as it is. Only the design changes.")
                        .font(CK.Font.callout)
                        .foregroundStyle(CK.Palette.graphite)

                    if results.isEmpty {
                        CKEmptyState(
                            title: String(localized: "No templates match"),
                            message: String(localized: "Try a different word, such as a category or an industry."),
                            systemImage: "magnifyingglass"
                        )
                    } else {
                        CKAdaptiveGrid(items: results, minWidth: 150) { (template: TemplateSpec, width: CGFloat) in
                            CKTemplateCard(
                                template: template,
                                width: width,
                                isSelected: template.id == currentTemplateID,
                                showsDetails: false,
                                action: {
                                    onPick(template.id)
                                    dismiss()
                                }
                            )
                        }
                    }
                }
                .padding(CK.Space.m)
            }
            .navigationTitle("Change template")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $filter.query, prompt: Text("Search templates"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .ckScreen()
        }
    }
}
