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
                Text("Drag the handles to reorder, or with VoiceOver use the Move up and Move down actions. Hidden sections stay saved but are left out of the document.")
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
                            Text(kind == .custom ? String(localized: "Custom section") : kind.defaultTitle)
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
                    .accessibilityLabel(kind == .custom ? String(localized: "Add custom section") : String(localized: "Add \(kind.defaultTitle)"))
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
            return String(localized: "\"\(section.title)\" and everything in it will be removed from this resume. Hide it instead if you may want it later.")
        }
        return String(localized: "The section and everything in it will be removed.")
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
            .accessibilityLabel(section.wrappedValue.isVisible ? String(localized: "Hide \(displayTitle(section.wrappedValue))") : String(localized: "Show \(displayTitle(section.wrappedValue))"))
            .modifier(reorderActions(section.wrappedValue))

            VStack(alignment: .leading, spacing: 0) {
                TextField("Section heading", text: section.title)
                    .font(CK.Font.body)
                    .foregroundStyle(section.wrappedValue.isVisible ? CK.Palette.ink : CK.Palette.graphite)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .accessibilityLabel("Section heading")
                    .accessibilityHint(positionHint(section.wrappedValue))
                    .modifier(reorderActions(section.wrappedValue))
                Text(section.wrappedValue.isVisible ? SectionOps.summaryLine(for: section.wrappedValue) : String(localized: "Hidden from the document"))
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minHeight: 52)
    }

    // MARK: VoiceOver reordering

    private func displayTitle(_ section: ResumeSection) -> String {
        let trimmed = section.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Untitled section") : trimmed
    }

    private func positionHint(_ section: ResumeSection) -> String {
        guard let index = sections.firstIndex(where: { $0.id == section.id }) else { return "" }
        let number: Int = index + 1
        let total: Int = sections.count
        return String(localized: "Position \(number) of \(total). Swipe up or down for move actions.")
    }

    private func reorderActions(_ section: ResumeSection) -> EdReorderActions {
        let index: Int = sections.firstIndex(where: { $0.id == section.id }) ?? 0
        return EdReorderActions(
            canMoveUp: index > 0,
            canMoveDown: index < sections.count - 1,
            moveUp: { move(section.id, by: -1) },
            moveDown: { move(section.id, by: 1) }
        )
    }

    private func move(_ id: UUID, by offset: Int) {
        guard let index = sections.firstIndex(where: { $0.id == id }) else { return }
        var copy = sections
        guard ListEditing.move(&copy, index: index, by: offset) else { return }
        let title: String = displayTitle(copy[index + offset])
        let number: Int = index + offset + 1
        let total: Int = copy.count
        sections = copy
        UIAccessibility.post(notification: .announcement,
                             argument: String(localized: "\(title) moved to position \(number) of \(total)"))
    }
}

/// "Move up" and "Move down" VoiceOver actions for a row in a reorderable list.
struct EdReorderActions: ViewModifier {
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void

    func body(content: Content) -> some View {
        content
            .accessibilityAction(named: Text("Move up")) {
                if canMoveUp { moveUp() }
            }
            .accessibilityAction(named: Text("Move down")) {
                if canMoveDown { moveDown() }
            }
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
