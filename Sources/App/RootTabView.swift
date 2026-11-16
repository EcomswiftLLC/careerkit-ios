import SwiftUI

/// Set to false if `CoverLetterListView` already contains its own NavigationStack.
private enum CKTabConfig {
    static let wrapCoverLettersInStack = true
}

struct RootTabView: View {
    @EnvironmentObject private var appState: AppState

    /// Changing this rebuilds the browse tabs (and their navigation paths) after a data reset.
    /// Profile keeps its identity so its confirmation message stays on screen.
    private var generation: Int { appState.dataResetGeneration }

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                modernTabs
            } else {
                legacyTabs
            }
        }
        .tint(CK.Palette.forest)
    }

    // MARK: iOS 18 and later: adaptive sidebar on iPad, tab bar on iPhone

    @available(iOS 18.0, *)
    private var modernTabs: some View {
        TabView(selection: $appState.selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) {
                HomeView()
                    .id(generation)
            }
            Tab("My Resumes", systemImage: "doc.text", value: AppTab.resumes) {
                MyResumesView()
                    .id(generation)
            }
            Tab("Templates", systemImage: "square.grid.2x2", value: AppTab.templates) {
                TemplateBrowserView()
                    .id(generation)
            }
            Tab("Cover Letters", systemImage: "envelope", value: AppTab.coverLetters) {
                CoverLettersTab()
                    .id(generation)
            }
            Tab("Profile", systemImage: "person.crop.circle", value: AppTab.profile) {
                ProfileView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    // MARK: iOS 17

    private var legacyTabs: some View {
        TabView(selection: $appState.selectedTab) {
            HomeView()
                .id(generation)
                .tabItem { Label("Home", systemImage: "house") }
                .tag(AppTab.home)
            MyResumesView()
                .id(generation)
                .tabItem { Label("My Resumes", systemImage: "doc.text") }
                .tag(AppTab.resumes)
            TemplateBrowserView()
                .id(generation)
                .tabItem { Label("Templates", systemImage: "square.grid.2x2") }
                .tag(AppTab.templates)
            CoverLettersTab()
                .id(generation)
                .tabItem { Label("Cover Letters", systemImage: "envelope") }
                .tag(AppTab.coverLetters)
            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppTab.profile)
        }
    }
}

private struct CoverLettersTab: View {
    var body: some View {
        if CKTabConfig.wrapCoverLettersInStack {
            NavigationStack {
                CoverLetterListView()
            }
        } else {
            CoverLetterListView()
        }
    }
}
