import SwiftUI

@main
struct CareerKitApp: App {
    @StateObject private var store = DocumentStore()
    @StateObject private var appState = AppState()
    @StateObject private var exportGate = ExportGate()
    @StateObject private var ads = AdsManager.shared

    init() {
        CKAppearance.configure()
    }

    var body: some Scene {
        WindowGroup {
            CKRootContainer()
                .environmentObject(store)
                .environmentObject(appState)
                .environmentObject(exportGate)
                .environmentObject(ads)
                .preferredColorScheme(appState.appearance.colorScheme)
                .tint(CK.Palette.forest)
        }
    }
}

/// Chooses between onboarding and the main tabs, and starts ads only after the first frame
/// and only once the person is past onboarding. Launch is never blocked by ads.
struct CKRootContainer: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var ads: AdsManager
    @EnvironmentObject private var store: DocumentStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var adsStarted = false

    var body: some View {
        ZStack {
            if appState.hasCompletedOnboarding {
                RootTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : Animation.easeInOut(duration: 0.3), value: appState.hasCompletedOnboarding)
        .task(id: appState.hasCompletedOnboarding) {
            await startAdsWhenReady()
        }
        .onChange(of: scenePhase) { _, phase in
            // Save immediately whenever the app leaves the foreground.
            if phase == .background || phase == .inactive {
                store.flushNow()
            }
        }
    }

    private func startAdsWhenReady() async {
        guard appState.hasCompletedOnboarding, !adsStarted else { return }
        // Let the first frame draw before any consent or ad work begins.
        try? await Task.sleep(nanoseconds: 400_000_000)
        guard !Task.isCancelled, !adsStarted else { return }
        adsStarted = true
        await ads.start()
    }
}
