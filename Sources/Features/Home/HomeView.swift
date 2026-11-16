import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var path: [AppRoute] = []
    @State private var showBlank = false
    @State private var showImport = false
    @State private var showATSPicker = false
    @State private var previewTemplate: TemplateSpec?
    @State private var heroSpread = false
    @State private var toast: String?

    private var activeResumes: [Resume] {
        store.resumes
            .filter { !$0.isArchived }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ResumeActionHost(
                openEditor: { id in path.append(.editor(id)) },
                openPreview: { id in path.append(.preview(id)) }
            ) { actions in
                dashboard(actions)
            }
            .toolbar(.hidden, for: .navigationBar)
            .ckScreen()
            .appRouteDestinations()
            .ckBlankResumeSheet(isPresented: $showBlank) { newID in
                path.append(.editor(newID))
            }
            .ckImportResumeSheet(isPresented: $showImport) { newID in
                path.append(.editor(newID))
            }
            .templatePreviewSheet($previewTemplate) { newID in
                path.append(.editor(newID))
            }
            .sheet(isPresented: $showATSPicker) {
                CKResumePickerSheet(
                    title: String(localized: "ATS check"),
                    message: String(localized: "Pick the resume to review. The check gives general formatting guidance. It is not a score from any employer's system."),
                    resumes: activeResumes
                ) { id in
                    showATSPicker = false
                    CKDeferred.afterDismiss { path.append(.atsCheck(id)) }
                }
            }
            .ckToast($toast)
        }
    }

    // MARK: Dashboard

    private func dashboard(_ actions: CKResumeActions) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CK.Space.xl) {
                header
                    .padding(.horizontal, CK.Space.m)

                if activeResumes.isEmpty {
                    emptyHero
                        .padding(.horizontal, CK.Space.m)
                } else {
                    createButtons
                        .padding(.horizontal, CK.Space.m)
                    recentSection(actions)
                }

                templatesSection
                coverLetterSection
                    .padding(.horizontal, CK.Space.m)
                toolsSection
                    .padding(.horizontal, CK.Space.m)
                CKFreeModelCard(learnMore: { path.append(.howExportsWork) })
                    .padding(.horizontal, CK.Space.m)

                // End-of-content banner (inline adaptive). Spacing and label only appear once an ad loads.
                CKInlineBanner()
                    .padding(.horizontal, CK.Space.m)
            }
            .padding(.vertical, CK.Space.m)
            .frame(maxWidth: 820)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Header

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12: base = String(localized: "Good morning")
        case 12..<18: base = String(localized: "Good afternoon")
        default: base = String(localized: "Good evening")
        }
        let name = appState.greetingName
        return name.isEmpty ? base : "\(base), \(name)"
    }

    private var subtitle: String {
        guard let latest = activeResumes.first else {
            return String(localized: "Let's build your first resume.")
        }
        let count = activeResumes.count
        let noun = count == 1 ? String(localized: "1 resume") : String(localized: "\(count) resumes")
        return String(localized: "You have \(noun). \"\(latest.title)\" is the one you edited last.")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: CK.Space.m) {
            VStack(alignment: .leading, spacing: CK.Space.s) {
                Text(greeting)
                    .ckTitle(32)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.graphite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button {
                appState.selectedTab = .profile
            } label: {
                avatar
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Profile and settings"))
        }
    }

    private var avatar: some View {
        let initial = appState.greetingName.first.map { String($0).uppercased() }
        return ZStack {
            Circle().fill(CK.Palette.stone)
            Circle().strokeBorder(CK.Palette.hairline, lineWidth: 0.5)
            if let initial {
                Text(initial)
                    .font(CK.Font.headline(17))
                    .foregroundStyle(CK.Palette.forest)
            } else {
                Image(systemName: "person")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(CK.Palette.forest)
            }
        }
        .frame(width: 44, height: 44)
        .contentShape(Circle())
    }

    // MARK: Create

    private var createButtons: some View {
        VStack(spacing: CK.Space.s + 4) {
            Button {
                appState.selectedTab = .templates
            } label: {
                Text("Create new resume")
            }
            .buttonStyle(.ckPrimary)

            Button {
                showBlank = true
            } label: {
                Text("Create from scratch")
            }
            .buttonStyle(.ckSecondary)
        }
    }

    private var emptyHero: some View {
        VStack(spacing: CK.Space.l) {
            CKPaperStack(spread: heroSpread)
                .animation(
                    reduceMotion ? nil : Animation.spring(response: 0.7, dampingFraction: 0.8).delay(0.15),
                    value: heroSpread
                )
                .onAppear { heroSpread = true }
            VStack(spacing: CK.Space.s) {
                Text("Start your first resume")
                    .ckTitle(26)
                    .multilineTextAlignment(.center)
                Text("Pick a template and fill in the sections, or begin on a blank page. Everything stays on this device.")
                    .font(CK.Font.callout)
                    .foregroundStyle(CK.Palette.graphite)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            createButtons
            Button {
                showImport = true
            } label: {
                Label("Import an existing resume", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.ckSecondary)
            .accessibilityHint("Reads a PDF or pasted text on this device")
        }
        .frame(maxWidth: 460)
        .frame(maxWidth: .infinity)
        .padding(.vertical, CK.Space.s)
    }

    // MARK: Sections

    private func recentSection(_ actions: CKResumeActions) -> some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            CKSectionHeader(
                title: String(localized: "Recent resumes"),
                actionTitle: String(localized: "See all"),
                action: { appState.selectedTab = .resumes }
            )
            .padding(.horizontal, CK.Space.m)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: CK.Space.m) {
                    ForEach(activeResumes.prefix(8)) { resume in
                        CKResumeTile(resume: resume, actions: actions, width: 168, menuStyle: .compact)
                    }
                }
                .padding(.horizontal, CK.Space.m)
                .padding(.bottom, CK.Space.xs)
            }
        }
    }

    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            CKSectionHeader(
                title: String(localized: "Templates"),
                subtitle: String(localized: "30 designs, all free"),
                actionTitle: String(localized: "Browse all"),
                action: { appState.selectedTab = .templates }
            )
            .padding(.horizontal, CK.Space.m)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: CK.Space.m) {
                    ForEach(Array(TemplateLibrary.all.prefix(10))) { template in
                        CKTemplateCard(
                            template: template,
                            width: 136,
                            showsDetails: false,
                            action: { previewTemplate = template }
                        )
                    }
                }
                .padding(.horizontal, CK.Space.m)
                .padding(.bottom, CK.Space.xs)
            }
        }
    }

    private var coverLetterSection: some View {
        CKCoverLetterShortcut { appState.selectedTab = .coverLetters }
    }

    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            CKSectionHeader(title: String(localized: "Career tools"))
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: CK.Space.s + 4) { toolTiles }
            } else {
                HStack(alignment: .top, spacing: CK.Space.s + 4) { toolTiles }
            }
        }
    }

    @ViewBuilder
    private var toolTiles: some View {
        CKToolTile(
            systemImage: "checklist",
            title: String(localized: "ATS check"),
            detail: String(localized: "Review one resume's formatting"),
            action: startATSCheck
        )
        CKToolTile(
            systemImage: "envelope.open",
            title: String(localized: "Cover letter"),
            detail: String(localized: "Write one to go with it"),
            action: { appState.selectedTab = .coverLetters }
        )
        CKToolTile(
            systemImage: "doc",
            title: String(localized: "Blank resume"),
            detail: String(localized: "Start on an empty page"),
            action: { showBlank = true }
        )
    }

    private func startATSCheck() {
        let resumes = activeResumes
        switch resumes.count {
        case 0:
            toast = String(localized: "Create a resume first, then run the ATS check on it.")
        case 1:
            path.append(.atsCheck(resumes[0].id))
        default:
            showATSPicker = true
        }
    }
}
