import SwiftUI

@main
struct CareerKitApp: App {
    @StateObject private var store = DocumentStore()
    @StateObject private var appState = AppState()
    @StateObject private var exportGate = ExportGate()
    @StateObject private var exportStore = ExportStore.makeForLaunch()
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
                .environmentObject(exportStore)
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
    @EnvironmentObject private var exportStore: ExportStore
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
        // App Store rating prompt, only after a finished export (see ReviewPromptPolicy).
        .ckReviewPromptHost()
        .task {
            #if DEBUG
            CKScreenshotSupport.seedIfRequested(store: store, appState: appState)
            #endif
        }
        .task {
            // Purchased exports and Premium: listen for store updates, refresh purchases and prices.
            exportStore.start()
        }
        .task {
            // Exported PDFs and backups left in tmp by an earlier session (older than one hour).
            await CKTempFiles.cleanStaleInBackground()
        }
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
        #if DEBUG
        if CKScreenshotSupport.isActive { return }
        #endif
        guard appState.hasCompletedOnboarding, !adsStarted else { return }
        // Let the first frame draw before any consent or ad work begins.
        try? await Task.sleep(nanoseconds: 400_000_000)
        guard !Task.isCancelled, !adsStarted else { return }
        adsStarted = true
        await ads.start()
    }
}
