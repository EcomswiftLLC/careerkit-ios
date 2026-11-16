import SwiftUI

/// "Writing help" menu for a summary or a bullet block. Shows nothing at all where on-device writing help
/// is unavailable, so those devices see the editor exactly as before. Call sites also check
/// `WritingAssist.isAvailable` so no empty row or spacing is added.
struct WritingAssistButton: View {
    let target: WritingAssistTarget
    /// The current text, captured when a mode is chosen.
    let text: String
    /// Role line for bullets, or the resume's work experience for a summary.
    var context: String = ""
    /// Called only after the person taps "Use suggestion".
    let onAccept: (String) -> Void

    @State private var request: WritingAssistRequest?

    var body: some View {
        if let engine = WritingAssist.makeEngine(), engine.availability.showsEntryPoint {
            Menu {
                ForEach(WritingAssistMode.modes(for: target)) { mode in
                    Button {
                        request = WritingAssistRequest(mode: mode, target: target, original: text, context: context)
                    } label: {
                        Label(mode.title, systemImage: mode.systemImage)
                    }
                    .disabled(!mode.canRun(text: text, context: context))
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 14, weight: .medium))
                        .accessibilityHidden(true)
                    Text("Writing help")
                        .font(CK.Font.label)
                }
                .foregroundStyle(CK.Palette.forest)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Writing help")
            .accessibilityHint("Suggests new wording on this device. Nothing changes until you choose Use suggestion.")
            .sheet(item: $request) { item in
                WritingAssistSheet(request: item, engine: engine, onAccept: onAccept)
            }
        }
    }
}

/// Small "Undo" link shown after a suggestion was used, while the text is still exactly that suggestion.
struct WritingAssistUndoButton: View {
    let action: () -> Void

    var body: some View {
        EdTextButton(title: String(localized: "Undo"), systemImage: "arrow.uturn.backward", action: action)
            .accessibilityLabel("Undo writing help")
            .accessibilityHint("Puts back your text from before the suggestion")
    }
}
