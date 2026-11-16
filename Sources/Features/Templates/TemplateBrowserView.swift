import SwiftUI

/// The Templates tab. Everything is free, so there is no free or premium filter.
struct TemplateBrowserView: View {
    @State private var path: [AppRoute] = []
    @State private var filter = CKTemplateFilter()
    @State private var previewTemplate: TemplateSpec?
    /// One banner for this screen, kept while filters toggle the no-results state.
    @StateObject private var bannerSlot = BannerAdSlot()

    private var results: [TemplateSpec] {
        filter.apply(to: TemplateLibrary.all)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: CK.Space.l) {
                    filterBars

                    if results.isEmpty {
                        CKEmptyState(
                            title: String(localized: "No templates match"),
                            message: String(localized: "Try fewer filters or a different word. You can search by name, industry, level or style."),
                            systemImage: "magnifyingglass",
                            primaryTitle: String(localized: "Clear filters"),
                            primaryAction: { filter.reset() }
                        )
                    } else if filter.isActive {
                        flatResults
                    } else {
                        sectionedResults
                    }

                    // No banner on the no-results state. Otherwise one inline banner after the last template.
                    if !results.isEmpty {
                        CKInlineBanner(slot: bannerSlot)
                            .padding(.horizontal, CK.Space.m)
                    }
                }
                .padding(.vertical, CK.Space.s)
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Templates")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $filter.query, prompt: Text("Search by name, industry or style"))
            .ckScreen()
            .appRouteDestinations()
            .templatePreviewSheet($previewTemplate) { newID in
                path.append(.editor(newID))
            }
        }
    }

    // MARK: Filters

    private var categoryOptions: [TemplateCategory?] {
        var options: [TemplateCategory?] = [nil]
        options.append(contentsOf: TemplateCategory.allCases.map { Optional($0) })
        return options
    }

    private var filterBars: some View {
        VStack(alignment: .leading, spacing: 0) {
            CKFilterChipBar(options: categoryOptions, selection: $filter.category) { (category: TemplateCategory?) -> String in
                category?.rawValue ?? String(localized: "All")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CK.Space.s) {
                    CKFilterMenuChip(name: String(localized: "Industry"), options: Industry.allCases, selection: $filter.industry) { (value: Industry) -> String in
                        value.rawValue
                    }
                    CKFilterMenuChip(name: String(localized: "Level"), options: ProfessionalLevel.allCases, selection: $filter.level) { (value: ProfessionalLevel) -> String in
                        value.rawValue
                    }
                    CKFilterMenuChip(name: String(localized: "Style"), options: DesignStyle.allCases, selection: $filter.style) { (value: DesignStyle) -> String in
                        value.rawValue
                    }
                    CKFilterMenuChip(name: String(localized: "Length"), options: CKTemplateFilter.Length.allCases, selection: $filter.length) { (value: CKTemplateFilter.Length) -> String in
                        value.rawValue
                    }
                    CKToggleChip(name: String(localized: "ATS friendly"), systemImage: "checkmark.seal", isOn: $filter.atsOnly)
                    if filter.hasFacets {
                        Button {
                            filter.reset()
                        } label: {
                            Text("Clear")
                                .font(CK.Font.label)
                                .foregroundStyle(CK.Palette.forest)
                                .padding(.horizontal, 8)
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, CK.Space.m)
            }
        }
    }

    // MARK: Results

    private var flatResults: some View {
        VStack(alignment: .leading, spacing: CK.Space.m) {
            Text(resultCountText)
                .font(CK.Font.callout)
                .foregroundStyle(CK.Palette.graphite)
                .padding(.horizontal, CK.Space.m)
                .accessibilityAddTraits(.isHeader)
            grid(for: results)
        }
    }

    private var sectionedResults: some View {
        VStack(alignment: .leading, spacing: CK.Space.xl) {
            ForEach(CKTemplateFilter.grouped(results), id: \.category) { group in
                VStack(alignment: .leading, spacing: CK.Space.m) {
                    CKSectionHeader(
                        title: group.category.rawValue,
                        subtitle: CKTemplateFilter.summary(for: group.category)
                    )
                    .padding(.horizontal, CK.Space.m)
                    grid(for: group.templates)
                }
            }
        }
    }

    private func grid(for templates: [TemplateSpec]) -> some View {
        CKAdaptiveGrid(items: templates, minWidth: 156) { (template: TemplateSpec, width: CGFloat) in
            CKTemplateCard(template: template, width: width, action: { previewTemplate = template })
        }
        .padding(.horizontal, CK.Space.m)
    }

    private var resultCountText: String {
        results.count == 1 ? String(localized: "1 template") : String(localized: "\(results.count) templates")
    }
}
