import SwiftUI

/// List of cover letters. This is the only editor-owned screen that shows a banner ad (after the last letter).
/// Expects to sit inside a NavigationStack.
struct CoverLetterListView: View {
    @EnvironmentObject private var store: DocumentStore

    @State private var search = ""
    @State private var showNew = false
    @State private var pendingOpenID: UUID?
    @State private var openedID: UUID?
    @State private var pendingDelete: CoverLetter?
    @StateObject private var bannerSlot = BannerAdSlot()

    init() {}

    private var letters: [CoverLetter] {
        let sorted = store.coverLetters.sorted { $0.updatedAt > $1.updatedAt }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sorted }
        return sorted.filter { letter in
            [letter.title, letter.companyName, letter.jobTitle, letter.recipientName]
                .contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    var body: some View {
        Group {
            if store.coverLetters.isEmpty {
                emptyState
            } else if letters.isEmpty {
                noResults
            } else {
                list
            }
        }
        .background(CK.Palette.ivory.ignoresSafeArea())
        .navigationTitle("Cover letters")
        .searchable(text: $search, prompt: "Search letters")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNew = true } label: {
                    Image(systemName: "plus").frame(width: 44, height: 44)
                }
                .accessibilityLabel("New cover letter")
            }
        }
        .sheet(isPresented: $showNew, onDismiss: {
            if let id = pendingOpenID {
                openedID = id
                pendingOpenID = nil
            }
        }) {
            NewCoverLetterSheet { id in pendingOpenID = id }
        }
        .navigationDestination(item: $openedID) { id in
            CoverLetterEditorView(letterID: id)
        }
        .confirmationDialog("Delete this cover letter?", isPresented: deleteBinding, titleVisibility: .visible, presenting: pendingDelete) { letter in
            Button("Delete letter", role: .destructive) {
                store.delete(coverLetterID: letter.id)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { letter in
            Text("\"\(letter.title)\" will be removed from this device. This cannot be undone.")
        }
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    // MARK: States

    private var emptyState: some View {
        VStack(spacing: CK.Space.m) {
            Image(systemName: "envelope.open")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(CK.Palette.forest)
                .accessibilityHidden(true)
            Text("No cover letters yet")
                .font(CK.Font.title(24))
                .foregroundStyle(CK.Palette.ink)
            Text("Write one letter per job. Pick a template, link a resume to fill in your details, and export when it reads well.")
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.graphite)
                .multilineTextAlignment(.center)
            Button("New cover letter") { showNew = true }
                .buttonStyle(.ckPrimary)
                .frame(maxWidth: 280)
                .padding(.top, CK.Space.s)
        }
        .padding(CK.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResults: some View {
        VStack(spacing: CK.Space.s) {
            Text("No letters match \"\(search)\"")
                .font(CK.Font.headline())
                .foregroundStyle(CK.Palette.ink)
            Text("Try a company name, a job title or part of the letter title.")
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.graphite)
        }
        .multilineTextAlignment(.center)
        .padding(CK.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List {
            ForEach(letters) { letter in
                row(letter)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 6, leading: CK.Space.m, bottom: 6, trailing: CK.Space.m))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { pendingDelete = letter } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { _ = store.duplicate(coverLetterID: letter.id) } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .tint(CK.Palette.forest)
                    }
                    .contextMenu {
                        Button("Duplicate", systemImage: "plus.square.on.square") { _ = store.duplicate(coverLetterID: letter.id) }
                        Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = letter }
                    }
            }

            // Banner ads are allowed on this browse screen only, never in the editor, and never on the
            // empty or no-results states. It is the last row (inline), so it never covers a letter or sits
            // against the tab bar. The screen owns the slot, so row recycling never sends a new request.
            CKInlineBanner(slot: bannerSlot)
                .listRowInsets(EdgeInsets(top: 0, leading: CK.Space.m, bottom: 0, trailing: CK.Space.m))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func row(_ letter: CoverLetter) -> some View {
        Button { openedID = letter.id } label: {
            HStack(alignment: .center, spacing: CK.Space.m) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(letter.title.isEmpty ? "Untitled letter" : letter.title)
                        .font(CK.Font.headline(18))
                        .foregroundStyle(CK.Palette.ink)
                        .lineLimit(1)
                    if let subtitle = subtitle(letter) {
                        Text(subtitle)
                            .font(CK.Font.callout)
                            .foregroundStyle(CK.Palette.graphite)
                            .lineLimit(1)
                    }
                    Text("\(EditorRender.coverTemplate(id: letter.templateID).name), edited \(letter.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.graphite)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(CK.Palette.graphite)
                    .accessibilityHidden(true)
            }
            .padding(CK.Space.m)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
            .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the letter")
    }

    private func subtitle(_ letter: CoverLetter) -> String? {
        let parts = [letter.jobTitle, letter.companyName].filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " at ")
    }
}
