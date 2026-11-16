import SwiftUI

/// Add, rename, hide, remove and reorder sections. Drag handles are always visible.
struct EdSectionManagerList: View {
    @Binding var sections: [ResumeSection]
    var onAdded: ((UUID) -> Void)? = nil

    @State private var pendingDelete: UUID?

    var body: some View {
        List {
            Section {
                ForEach($sections) { $section in
                    row($section)
                }
                .onMove { source, destination in
                    var copy = sections
                    ListEditing.move(&copy, fromOffsets: source, toOffset: destination)
                    sections = copy
                }
                .onDelete { offsets in
                    if let first = offsets.first, sections.indices.contains(first) {
                        pendingDelete = sections[first].id
                    }
                }
            } header: {
                Text("Sections on your resume")
            } footer: {
                Text("Drag the handles to reorder. Hidden sections stay saved but are left out of the document.")
            }

            Section {
                ForEach(SectionKind.allCases) { kind in
                    Button {
                        add(kind)
                    } label: {
                        HStack(spacing: CK.Space.s + 4) {
                            Image(systemName: kind.systemImage)
                                .frame(width: 24)
                                .foregroundStyle(CK.Palette.forest)
                                .accessibilityHidden(true)
                            Text(kind == .custom ? "Custom section" : kind.defaultTitle)
                                .font(CK.Font.body)
                                .foregroundStyle(CK.Palette.ink)
                            Spacer()
                            Image(systemName: "plus")
                                .foregroundStyle(CK.Palette.graphite)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Add \(kind == .custom ? "custom section" : kind.defaultTitle)")
                }
            } header: {
                Text("Add a section")
            } footer: {
                Text("You can add more than one custom section.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
        .confirmationDialog("Remove this section?", isPresented: deleteBinding, titleVisibility: .visible) {
            Button("Remove section", role: .destructive) {
                if let id = pendingDelete { sections.removeAll { $0.id == id } }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(deleteMessage)
        }
        .onDisappear { sections = SectionOps.normalized(sections) }
    }

    private var deleteMessage: String {
        if let id = pendingDelete, let section = sections.first(where: { $0.id == id }) {
            return "\"\(section.title)\" and everything in it will be removed from this resume. Hide it instead if you may want it later."
        }
        return "The section and everything in it will be removed."
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private func add(_ kind: SectionKind) {
        let section = SectionOps.newSection(kind: kind, existing: sections)
        sections.append(section)
        onAdded?(section.id)
    }

    private func row(_ section: Binding<ResumeSection>) -> some View {
        HStack(spacing: CK.Space.s) {
            Button {
                section.wrappedValue.isVisible.toggle()
            } label: {
                Image(systemName: section.wrappedValue.isVisible ? "eye" : "eye.slash")
                    .foregroundStyle(section.wrappedValue.isVisible ? CK.Palette.forest : CK.Palette.graphite)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(section.wrappedValue.isVisible ? "Hide \(section.wrappedValue.title)" : "Show \(section.wrappedValue.title)")

            VStack(alignment: .leading, spacing: 0) {
                TextField("Section heading", text: section.title)
                    .font(CK.Font.body)
                    .foregroundStyle(section.wrappedValue.isVisible ? CK.Palette.ink : CK.Palette.graphite)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                Text(section.wrappedValue.isVisible ? SectionOps.summaryLine(for: section.wrappedValue) : "Hidden from the document")
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
            }
        }
        .frame(minHeight: 52)
    }
}

/// Sheet wrapper used from the editor toolbar.
struct SectionManagerSheet: View {
    @Binding var sections: [ResumeSection]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            EdSectionManagerList(sections: $sections)
                .background(CK.Palette.ivory.ignoresSafeArea())
                .navigationTitle("Sections")
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
