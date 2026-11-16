import SwiftUI

/// Browsable library of example wording. Tapping "Use this" inserts the text; the user then edits it.
struct WritingExamplesSheet: View {
    enum Mode {
        case summaries
        case achievements

        var categories: [WritingExampleCategory] {
            switch self {
            case .summaries: return WritingExamples.summaryCategories
            case .achievements: return WritingExamples.achievementCategories
            }
        }

        var title: String {
            switch self {
            case .summaries: return "Summary examples"
            case .achievements: return "Achievement examples"
            }
        }

        var intro: String {
            switch self {
            case .summaries:
                return "Fictional examples to borrow structure and tone from. Change the details so they describe you."
            case .achievements:
                return "Each example starts with an action and ends with a result. Replace the numbers with your own, and only keep what is true for you."
            }
        }
    }

    let mode: Mode
    let onInsert: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: String
    @State private var inserted: Set<String> = []

    init(mode: Mode, onInsert: @escaping (String) -> Void) {
        self.mode = mode
        self.onInsert = onInsert
        _selectedID = State(initialValue: mode.categories.first?.id ?? "")
    }

    private var selected: WritingExampleCategory? {
        mode.categories.first(where: { $0.id == selectedID }) ?? mode.categories.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CK.Space.m) {
                    Text(mode.intro)
                        .font(CK.Font.callout)
                        .foregroundStyle(CK.Palette.graphite)
                    categoryChips
                    if let selected {
                        ForEach(selected.items, id: \.self) { example in
                            card(example)
                        }
                    }
                }
                .padding(CK.Space.m)
            }
            .background(CK.Palette.ivory.ignoresSafeArea())
            .navigationTitle(mode.title)
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

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CK.Space.s) {
                ForEach(mode.categories) { category in
                    let isSelected = category.id == selectedID
                    Button { selectedID = category.id } label: {
                        Text(category.name)
                            .font(CK.Font.label)
                            .foregroundStyle(isSelected ? CK.Palette.onForest : CK.Palette.ink)
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(Capsule().fill(isSelected ? CK.Palette.forest : CK.Palette.stone))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func card(_ example: String) -> some View {
        let wasInserted = inserted.contains(example)
        return VStack(alignment: .leading, spacing: CK.Space.s) {
            Text(example)
                .font(CK.Font.body)
                .foregroundStyle(CK.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button {
                    onInsert(example)
                    inserted.insert(example)
                    if mode == .summaries { dismiss() }
                } label: {
                    Label(wasInserted ? "Added" : "Use this", systemImage: wasInserted ? "checkmark" : "plus")
                        .font(CK.Font.label)
                        .foregroundStyle(wasInserted ? CK.Palette.graphite : CK.Palette.forest)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Inserts this text into your resume")
            }
        }
        .padding(CK.Space.m)
        .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
    }
}
