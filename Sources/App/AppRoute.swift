import SwiftUI

/// Pushed destinations shared by every tab's NavigationStack.
enum AppRoute: Hashable {
    case editor(UUID)
    case preview(UUID)
    case atsCheck(UUID)
    case howExportsWork
}

private struct AppRouteDestinations: ViewModifier {
    func body(content: Content) -> some View {
        content.navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .editor(let id):
                ResumeEditorView(resumeID: id)
                    .toolbar(.hidden, for: .tabBar)
            case .preview(let id):
                // Read-only preview plus an Export button (Sources/Features/MyResumes/ResumePreviewScreen.swift).
                ResumePreviewScreen(resumeID: id)
                    .toolbar(.hidden, for: .tabBar)
            case .atsCheck(let id):
                ATSCheckView(resumeID: id)
                    .toolbar(.hidden, for: .tabBar)
            case .howExportsWork:
                CKHowExportsWorkView()
            }
        }
    }
}

extension View {
    /// Attach once inside every NavigationStack that uses `AppRoute`.
    func appRouteDestinations() -> some View {
        modifier(AppRouteDestinations())
    }
}
