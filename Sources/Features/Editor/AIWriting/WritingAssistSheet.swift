import SwiftUI
import UIKit

/// Shows the person's text next to a suggestion. Nothing changes until they tap "Use suggestion".
struct WritingAssistSheet: View {
    let onAccept: (String) -> Void

    @StateObject private var model: WritingAssistViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var typeSize

    init(request: WritingAssistRequest, engine: any WritingAssistEngine, onAccept: @escaping (String) -> Void) {
        self.onAccept = onAccept
        _model = StateObject(wrappedValue: WritingAssistViewModel(request: request, engine: engine))
    }

    private var request: WritingAssistRequest { model.request }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CK.Space.m) {
                    comparison
                    Text("Suggested on your device. Check every fact before you use it.")
                        .font(CK.Font.caption)
                        .foregroundStyle(CK.Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(CK.Space.m)
            }
            .background(CK.Palette.ivory.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) { actions }
            .navigationTitle(request.mode.title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear {
            if model.phase == .idle { model.start() }
        }
        .onDisappear { model.cancel() }
        .onChange(of: model.phase) { _, newPhase in
            announce(newPhase)
        }
    }

    // MARK: Comparison

    /// Side by side on a wide screen at standard text sizes, stacked otherwise.
    private var comparison: some View {
        let sideBySide = sizeClass == .regular && !typeSize.isAccessibilitySize
        let layout = sideBySide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: CK.Space.m))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: CK.Space.m))
        return layout {
            originalBlock
            suggestionBlock
        }
    }

    @ViewBuilder
    private var originalBlock: some View {
        if request.mode.usesContextAsSource {
            block(title: String(localized: "Based on")) {
                Text("The work experience in this resume")
                    .font(CK.Font.body)
                    .foregroundStyle(CK.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            block(title: String(localized: "Your text")) {
                Text(verbatim: display(request.original))
                    .font(CK.Font.body)
                    .foregroundStyle(CK.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
    }

    private var suggestionBlock: some View {
        block(title: String(localized: "Suggestion")) {
            switch model.phase {
            case .idle, .working:
                HStack(spacing: CK.Space.s) {
                    ProgressView()
                        .accessibilityHidden(true)
                    Text("Writing a suggestion")
                        .font(CK.Font.body)
                        .foregroundStyle(CK.Palette.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: CK.Space.s)
                    EdTextButton(title: String(localized: "Cancel")) {
                        model.cancel()
                        dismiss()
                    }
                    .accessibilityHint("Stops and closes. Your text stays as it is.")
                }
            case .suggestion(let text):
                Text(verbatim: display(text))
                    .font(CK.Font.body)
                    .foregroundStyle(CK.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            case .noChange:
                Text("No changes to suggest. Your text already reads well.")
                    .font(CK.Font.body)
                    .foregroundStyle(CK.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            case .failed(let failure):
                VStack(alignment: .leading, spacing: CK.Space.s) {
                    HStack(alignment: .firstTextBaseline, spacing: CK.Space.s) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(CK.Palette.graphite)
                            .accessibilityHidden(true)
                        Text(failure.message)
                            .font(CK.Font.body)
                            .foregroundStyle(CK.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if failure.canRetry {
                        EdTextButton(title: String(localized: "Try again"), systemImage: "arrow.clockwise") { model.start() }
                    }
                }
            }
        }
    }

    private func block<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: CK.Space.s) {
            Overline(text: title)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CK.Space.m)
        .background(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).fill(CK.Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: CK.Radius.card, style: .continuous).strokeBorder(CK.Palette.hairline, lineWidth: 0.5))
    }

    /// Bullets read as bullets; a summary reads as written.
    private func display(_ text: String) -> String {
        guard request.target == .bullets else { return text }
        return WritingAssistText.splitBullets(text).map { "\u{2022} " + $0 }.joined(separator: "\n")
    }

    // MARK: Actions

    private var actions: some View {
        VStack(spacing: CK.Space.s) {
            Button {
                guard let text = model.suggestion else { return }
                onAccept(text)
                dismiss()
            } label: {
                Text("Use suggestion")
            }
            .buttonStyle(.ckPrimary)
            .disabled(model.suggestion == nil)
            .accessibilityHint("Replaces your text with the suggestion. You can undo it afterwards.")

            Button {
                model.cancel()
                dismiss()
            } label: {
                Text("Keep mine")
            }
            .buttonStyle(.ckSecondary)
            .accessibilityHint("Closes without changing your text")
        }
        .padding(.horizontal, CK.Space.m)
        .padding(.vertical, CK.Space.s)
        .background(CK.Palette.ivory.ignoresSafeArea())
    }

    private func announce(_ phase: WritingAssistViewModel.Phase) {
        let message: String
        switch phase {
        case .suggestion: message = String(localized: "Suggestion ready")
        case .noChange: message = String(localized: "No changes to suggest")
        case .failed(let failure): message = failure.message
        case .idle, .working: return
        }
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}
