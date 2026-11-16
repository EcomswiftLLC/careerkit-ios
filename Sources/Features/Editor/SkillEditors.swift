import SwiftUI

// MARK: - Token list (skills, tools, languages)

/// Editable list of short items shown as chips. Tap a chip to move or remove it. Type and press return to add.
struct EdTokenListEditor: View {
    @Binding var items: [String]
    var prompt: String

    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.s + 2) {
            if !items.isEmpty {
                EdFlowLayout(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { pair in
                        chip(index: pair.offset, text: pair.element)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(spacing: CK.Space.s) {
                TextField(prompt, text: $draft)
                    .font(CK.Font.body)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($fieldFocused)
                    .onSubmit { commit() }
                    .frame(minHeight: 44)
                Button("Add") { commit() }
                    .font(CK.Font.label)
                    .foregroundStyle(trimmedDraft.isEmpty ? CK.Palette.graphite.opacity(0.5) : CK.Palette.forest)
                    .frame(minWidth: 44, minHeight: 44)
                    .disabled(trimmedDraft.isEmpty)
            }
            Rectangle().fill(CK.Palette.hairline).frame(height: 1)
            Text("Separate several items with commas. Tap an item to move or remove it.")
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)
        }
    }

    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func commit() {
        let parts = TokenParsing.split(draft)
        guard !parts.isEmpty else { return }
        items = TokenParsing.appendUnique(existing: items, new: parts)
        draft = ""
        fieldFocused = true
    }

    private func chip(index: Int, text: String) -> some View {
        Menu {
            Button("Move earlier", systemImage: "arrow.left") { move(index, by: -1) }
                .disabled(index == 0)
            Button("Move later", systemImage: "arrow.right") { move(index, by: 1) }
                .disabled(index >= items.count - 1)
            Button("Remove", systemImage: "trash", role: .destructive) { remove(index) }
        } label: {
            Text(text)
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.ink)
                .padding(.horizontal, 14)
                .frame(minHeight: 40)
                .background(Capsule().fill(CK.Palette.stone))
                .overlay(Capsule().strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
        }
        .accessibilityLabel(text)
        .accessibilityHint("Opens options to move or remove")
    }

    private func move(_ index: Int, by offset: Int) {
        var copy = items
        if ListEditing.move(&copy, index: index, by: offset) { items = copy }
    }

    private func remove(_ index: Int) {
        var copy = items
        if ListEditing.remove(&copy, at: index) != nil { items = copy }
    }
}

// MARK: - Skill groups

struct SkillGroupsEditor: View {
    @Binding var section: ResumeSection

    @State private var pendingRemoval: UUID?

    private var isLanguages: Bool { section.kind == .languages }

    var body: some View {
        VStack(alignment: .leading, spacing: CK.Space.l) {
            ForEach(Array(section.skillGroups.enumerated()), id: \.element.id) { pair in
                groupCard(index: pair.offset)
            }
            EdTextButton(title: isLanguages ? "Add language group" : "Add skill group", systemImage: "plus") {
                section.skillGroups.append(SkillGroup())
            }
        }
        .confirmationDialog("Remove this group?", isPresented: removalBinding, titleVisibility: .visible) {
            Button("Remove group", role: .destructive) {
                if let id = pendingRemoval { section.skillGroups.removeAll { $0.id == id } }
                pendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("The group and its items will be removed.")
        }
    }

    private var removalBinding: Binding<Bool> {
        Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } })
    }

    @ViewBuilder
    private func groupCard(index: Int) -> some View {
        if section.skillGroups.indices.contains(index) {
            VStack(alignment: .leading, spacing: CK.Space.s + 2) {
                HStack(alignment: .bottom, spacing: 0) {
                    EdField(label: isLanguages ? "Group name (optional)" : "Group name, for example Tools",
                            text: nameBinding(index),
                            prompt: isLanguages ? "Languages" : "Technical")
                    EdMoreMenu(label: "Group actions") {
                        Button("Move up", systemImage: "arrow.up") { moveGroup(index, by: -1) }
                            .disabled(index == 0)
                        Button("Move down", systemImage: "arrow.down") { moveGroup(index, by: 1) }
                            .disabled(index >= section.skillGroups.count - 1)
                        Button("Remove group", systemImage: "trash", role: .destructive) { requestRemoval(index) }
                    }
                }
                EdTokenListEditor(items: itemsBinding(index),
                                  prompt: isLanguages ? "Add a language, for example Spanish, fluent" : "Add a skill")
            }
            .padding(CK.Space.m)
            .background(RoundedRectangle(cornerRadius: CK.Radius.chip + 2, style: .continuous).fill(CK.Palette.ivory))
            .overlay(RoundedRectangle(cornerRadius: CK.Radius.chip + 2, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
        }
    }

    private func nameBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { section.skillGroups.indices.contains(index) ? section.skillGroups[index].name : "" },
            set: { if section.skillGroups.indices.contains(index) { section.skillGroups[index].name = $0 } }
        )
    }

    private func itemsBinding(_ index: Int) -> Binding<[String]> {
        Binding(
            get: { section.skillGroups.indices.contains(index) ? section.skillGroups[index].items : [] },
            set: { if section.skillGroups.indices.contains(index) { section.skillGroups[index].items = $0 } }
        )
    }

    private func moveGroup(_ index: Int, by offset: Int) {
        var groups = section.skillGroups
        if ListEditing.move(&groups, index: index, by: offset) { section.skillGroups = groups }
    }

    private func requestRemoval(_ index: Int) {
        guard section.skillGroups.indices.contains(index) else { return }
        let group = section.skillGroups[index]
        if group.items.isEmpty && group.name.isEmpty {
            section.skillGroups.remove(at: index)
        } else {
            pendingRemoval = group.id
        }
    }
}
