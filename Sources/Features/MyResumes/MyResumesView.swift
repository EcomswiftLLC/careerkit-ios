import SwiftUI

struct MyResumesView: View {
    enum Scope: Hashable, CaseIterable {
        case active
        case archived
    }

    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var appState: AppState

    @State private var path: [AppRoute] = []
    @State private var query = ""
    @State private var scope: Scope = .active
    @State private var showBlank = false
    @State private var showCompare = false
    @State private var showImport = false
    @AppStorage("ck.myResumes.sort") private var sortRaw = CKResumeSort.lastEdited.rawValue
    @AppStorage("ck.myResumes.grid") private var useGrid = false
    /// One banner for this screen, shared by the list and grid layouts.
    @StateObject private var bannerSlot = BannerAdSlot()

    private var sort: CKResumeSort {
        CKResumeSort(rawValue: sortRaw) ?? .lastEdited
    }

    private var activeCount: Int { store.resumes.filter { !$0.isArchived }.count }
    private var archivedCount: Int { store.resumes.filter { $0.isArchived }.count }

    private var items: [Resume] {
        let wantArchived = scope == .archived
        let scoped = store.resumes.filter { $0.isArchived == wantArchived }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matched = trimmed.isEmpty ? scoped : scoped.filter { CKResumeSearch.matches($0, query: trimmed) }
        return sort.sorted(matched)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ResumeActionHost(
                openEditor: { id in path.append(.editor(id)) },
                openPreview: { id in path.append(.preview(id)) }
            ) { actions in
                VStack(spacing: 0) {
                    CKFilterChipBar(options: Scope.allCases, selection: $scope) { (value: Scope) -> String in
                        scopeTitle(value)
                    }
                    if items.isEmpty {
                        emptyState
                    } else if useGrid {
                        gridContent(actions)
                    } else {
                        listContent(actions)
                    }
                }
            }
            .navigationTitle("My Resumes")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: Text("Search resumes"))
            .toolbar { toolbarContent }
            .ckScreen()
            .appRouteDestinations()
            .ckBlankResumeSheet(isPresented: $showBlank) { newID in
                path.append(.editor(newID))
            }
            .ckImportResumeSheet(isPresented: $showImport) { newID in
                path.append(.editor(newID))
            }
            .sheet(isPresented: $showCompare) {
                CKCompareVersionsView(candidates: store.resumes.sorted { $0.updatedAt > $1.updatedAt })
            }
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if store.resumes.count >= 2 {
                Button {
                    showCompare = true
                } label: {
                    Label("Compare versions", systemImage: "rectangle.split.2x1")
                }
            }
            Menu {
                Picker("Sort by", selection: $sortRaw) {
                    ForEach(CKResumeSort.allCases) { option in
                        Text(option.title).tag(option.rawValue)
                    }
                }
                Picker("View as", selection: $useGrid) {
                    Label("List", systemImage: "list.bullet").tag(false)
                    Label("Grid", systemImage: "square.grid.2x2").tag(true)
                }
            } label: {
                Label("Sort and view", systemImage: "arrow.up.arrow.down")
            }
            Menu {
                Button {
                    appState.selectedTab = .templates
                } label: {
                    Label("Choose a template", systemImage: "square.grid.2x2")
                }
                Button {
                    showBlank = true
                } label: {
                    Label("Blank resume", systemImage: "doc")
                }
                Button {
                    showImport = true
                } label: {
                    Label("Import resume", systemImage: "square.and.arrow.down")
                }
            } label: {
                Label("New resume", systemImage: "plus")
            }
        }
    }

    // MARK: Content

    private func scopeTitle(_ scope: Scope) -> String {
        switch scope {
        case .active: return String(localized: "Resumes (\(activeCount))")
        case .archived: return String(localized: "Archived (\(archivedCount))")
        }
    }

    private var summaryLine: String {
        let count = items.count
        let noun = count == 1 ? String(localized: "1 resume") : String(localized: "\(count) resumes")
        return String(localized: "\(noun), sorted by \(sort.title.lowercased())")
    }

    private func listContent(_ actions: CKResumeActions) -> some View {
        List {
            Text(summaryLine)
                .font(CK.Font.caption)
                .foregroundStyle(CK.Palette.graphite)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)

            ForEach(items) { resume in
                CKResumeRow(resume: resume, actions: actions)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(CK.Palette.hairline)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            actions.delete(resume)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button {
                            actions.toggleArchive(resume)
                        } label: {
                            Label(resume.isArchived ? "Unarchive" : "Archive",
                                  systemImage: resume.isArchived ? "tray.and.arrow.up" : "archivebox")
                        }
                        .tint(CK.Palette.graphite)
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            actions.duplicate(resume)
                        } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .tint(CK.Palette.forest)
                    }
            }

            // End-of-list banner. The screen owns the slot, so row recycling never sends a new request.
            CKInlineBanner(slot: bannerSlot)
                .listRowInsets(EdgeInsets(top: 0, leading: CK.Space.m, bottom: 0, trailing: CK.Space.m))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func gridContent(_ actions: CKResumeActions) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CK.Space.m) {
                Text(summaryLine)
                    .font(CK.Font.caption)
                    .foregroundStyle(CK.Palette.graphite)
                    .padding(.horizontal, CK.Space.m)
                CKAdaptiveGrid(items: items, minWidth: 156) { (resume: Resume, width: CGFloat) in
                    CKResumeTile(resume: resume, actions: actions, width: width, menuStyle: .full)
                }
                .padding(.horizontal, CK.Space.m)

                CKInlineBanner(slot: bannerSlot)
                    .padding(.horizontal, CK.Space.m)
            }
            .padding(.vertical, CK.Space.s)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        VStack {
            Spacer(minLength: CK.Space.l)
            if !trimmed.isEmpty {
                CKEmptyState(
                    title: String(localized: "No matches"),
                    message: String(localized: "Nothing in this list matches \"\(trimmed)\". Check the spelling or try a template name."),
                    systemImage: "magnifyingglass"
                )
            } else if scope == .archived {
                CKEmptyState(
                    title: String(localized: "Nothing archived"),
                    message: String(localized: "Archive a resume to hide it from your main list. It stays on this device and you can bring it back at any time."),
                    systemImage: "archivebox"
                )
            } else {
                CKEmptyState(
                    title: String(localized: "No resumes yet"),
                    message: String(localized: "Start from a template, or begin on a blank page. Everything is saved on this device."),
                    systemImage: "doc.text",
                    primaryTitle: String(localized: "Choose a template"),
                    primaryAction: { appState.selectedTab = .templates },
                    secondaryTitle: String(localized: "Start from scratch"),
                    secondaryAction: { showBlank = true }
                )
            }
            Spacer(minLength: CK.Space.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
